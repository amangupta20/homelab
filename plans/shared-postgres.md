---
type: plan
status: "not started"
verified: "no (design from research 2026-10-31; nothing built)"
hosts:
  - XCP-ng host
  - TrueNAS VM
tags:
  - plan
  - postgres
  - database
  - pigsty
---

# Shared Postgres

**Status:** not started. Part of the migration (`plans/migration.md`); its
first step waits on the owner's answers under "Decide before step 1".
**Goal:** one Postgres server at home, set up with Pigsty, that apps share
with one user and one database each — so every app gets the same backups,
point-in-time restore and monitoring instead of a forgotten database container
per stack.
**Done when:** a scratch-instance point-in-time restore of one migrated app's
database is recorded in `journal/`, and an alert fires when WAL archiving is
broken on purpose.

Everything here comes from a research conversation on 2026-10-31. Numbers
marked as guesses were not measured; commands are **UNTESTED** unless they say
otherwise. The multi-site parts (a standby on the VPS, reads from the nearest
copy, FerretDB) are not in this plan: `ideas/multi-site-postgres.md`.

## What Pigsty is, and what runs where

Pigsty is an installer plus one config file (`pigsty.yml`), not a cluster
manager that keeps running. It logs into each machine over SSH and installs
and configures the software (Ansible underneath), then steps away. The
database keeps running without it.

| Machine | Runs | If it dies |
|---|---|---|
| **Manager VM** (no Postgres) | `pigsty.yml` and Pigsty's commands; dashboards and alerts (Grafana, metrics, logs); etcd member 3 | Databases, replication, failover and backups keep working. Lost: dashboards, alerts, Pigsty commands. Rebuilt from `pigsty.yml` |
| **Database node(s)** | Postgres; Patroni (decides which node is primary); etcd; HAProxy and PgBouncer (where apps connect); pgBackRest (backups) | That cluster's primary moves to a replica if it has one; otherwise restore from backup |

Separate clusters for separate purposes (`pg-test`, `pg-prod`) are separate
blocks in `pigsty.yml`, each with its own primary, users and backups; one etcd
serves them all. Pigsty runs one Postgres cluster per machine, as recalled
(check), so each cluster gets its own VM. New Postgres versions go on
`pg-test` first.

`pigsty.yml` holds passwords. It never enters this public repo as it is: the
passwords live in OpenBao (`systems/openbao.md`), and only a copy with
`__PASTE_ONCE__` placeholders may be committed.

## Sizing

| Piece | Size | Source |
|---|---|---|
| Any Pigsty node | hard minimum 1 CPU / 1 GB, recommended floor 1 CPU / 2 GB | Pigsty docs ("Prepare Resources", read 2026-10-31) |
| Manager VM, admin part and etcd only | 1 vCPU / 1 GB | guess |
| Manager VM with dashboards | 2 GB | guess |
| `pg-test` node | 1 vCPU / 2 GB | Pigsty recommended floor; enough to learn on |
| Patroni + etcd + HAProxy + PgBouncer + exporters, per node | ~200–400 MB idle, negligible CPU | guess |

Postgres itself takes most of a node's memory, and that is set in config:
Pigsty sizes Postgres's cache (`shared_buffers`) from the node's RAM (about a
quarter, as recalled). On a small VM, lower it in `pigsty.yml`.

Disk: etcd and Postgres both wait for the disk to confirm each write (fsync).
Put them on NVMe or SSD, not disks shared with busy VMs. Etcd's hardware guide
asks for WAL fsync p99 under 10 ms and backend commit p99 under 25 ms. Its
suggested check, before installing (**UNTESTED** here):

```bash
mkdir test-data
fio --rw=write --ioengine=sync --fdatasync=1 --directory=test-data \
    --size=22m --bs=2300 --name=etcd-disk-check
# read the fsync/fdatasync 99th percentile in the output
```

## Network latency (etcd and Patroni)

Etcd keeps members in agreement with heartbeats, and a member that hears
nothing for an *election timeout* starts a vote for a new leader. The
defaults, as recalled from etcd's tuning guide: **heartbeat 100 ms, election
timeout 1000 ms**. The guide's rules: the heartbeat should be roughly the round
trip time (RTT) between members, and the election timeout **at least about
10× the RTT**.

| RTT between etcd members | What to do |
|---|---|
| same LAN, under 1 ms | defaults |
| same region, about 1–50 ms | defaults usually fine (guess) |
| across continents, about 150–250 ms | tune: heartbeat ~250 ms, election timeout 2.5–5 s |

- **Jitter matters more than the average.** A link that is usually 30 ms but
  spikes to 800 ms causes false elections: members decide the leader is gone
  when it was only slow. Measure over hours with `mtr`, not with one `ping`.
- **Patroni adds its own margin.** It rides out etcd trouble for
  `retry_timeout` (10 s default) and holds the leader lock for `ttl` (30 s)
  before giving up; Pigsty sets these from its recovery-time target
  (`pg_rto`, as recalled). Short blips do not demote the primary; a sustained
  outage does.
- **Rule for this plan: every etcd member sits on the home LAN.** A member on
  the VPS would make the home primary depend on the home internet connection
  (`ideas/multi-site-postgres.md`, "Why etcd must not span home and the VPS").
- **Apps:** a query from an app to a database over the internet pays one round
  trip each time; apps that send many small queries feel it most. Keep each
  app on the same LAN as the database it writes to.
- **Watch it:** etcd reports both kinds of latency as
  `etcd_network_peer_round_trip_time_seconds` and
  `etcd_disk_wal_fsync_duration_seconds`; Pigsty's dashboards graph them.

## Backups

Follows `decisions/backup-tiers.md` (proposed).

- **pgBackRest**, with `repo1` on Garage (tier 1) and `repo2` encrypted
  offsite (tier 2, if the owner puts the database there).
- **Point-in-time restore:** a base backup plus the WAL (write-ahead log, the
  record of every change) archived after it lets you restore to any second
  in between, or to a named point (`SELECT pg_create_restore_point('before-x');`).
- **Retention by days:** `repo1-retention-full-type=time`. Data older than the
  window remains until the next full backup ages out: oldest kept ≈ window +
  time between full backups.
- **`archive_timeout = 60`**, so a quiet database still ships its changes at
  least every minute.
- **Restores cover the whole server, not one database.** To roll back one
  app, restore to a scratch instance and copy that app's database across.

Failure to watch: if archiving fails (offsite down, expired key, full bucket),
Postgres keeps every WAL file locally until the disk fills and Postgres stops.
A replication slot left behind by a removed replica does the same; cap slots
with `max_slot_wal_keep_size`. Alert on archive failures and on `pg_wal` size.

## Security checklist

- Listens on the LAN or tailnet only, never a public address.
- `hostssl` lines with `scram-sha-256` in `pg_hba.conf`, one per app and
  source address.
- One role and one database per app; `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC`
  for every database; no app gets superuser. Extensions an app needs are
  created by the admin.
- Minor versions kept current: privilege-escalation bugs would turn one app's
  password into every app's data.
- App passwords in OpenBao.
- Dashboards (Grafana) on the LAN or tailnet only, default admin password
  changed before first use.

## Adding an app

1. Create its role and database, plus any extension it needs (as admin).
2. Store the password in OpenBao.
3. Remove the bundled database from its compose file and point it at HAProxy.
4. Add its `pg_hba.conf` line.
5. Removing an app later: drop its database and role.

Apps that pin unusual database versions or extensions stay bundled. Immich is
the known case: it pins a VectorChord version that changes with Immich
releases. Pigsty packages VectorChord, so sharing is possible, but each Immich
upgrade could need a server-side extension upgrade first.

## Changing the primary, shrinking, leaving

- **Planned switch:** `patronictl switchover` — waits until the replica has
  caught up, so nothing is lost. **Unplanned:** Patroni promotes a replica on
  its own; with asynchronous replication the last few seconds can be lost. A
  one-node cluster has nothing to switch to.
- **Two nodes to one:** switch over first if the surviving node is the
  replica; remove the other with Pigsty's remove command; remove etcd members
  one at a time with `etcdctl member remove`, never by switching them off
  (losing the majority stops the primary); check `pg_replication_slots` for
  leftovers.
- **Leaving Pigsty:** low lock-in. It installs standard Postgres, Patroni and
  pgBackRest. Ways out: `pg_dump` per database (downtime while it runs);
  stream to the new server and promote it (same major version, about a minute
  down); logical replication (across versions and platforms). Rebuild users,
  `pg_hba` rules and monitoring on the new side; existing pgBackRest backups
  stay readable. Estimated an afternoon for a small lab (guess).

## Decide before step 1 (owner)

- Which apps move to the shared server first, and which stay bundled.
- Where apps that run on the VPS get their database: from this server over the
  tailnet (a round trip per query), or bundled as today.
- One home database node, or two on separate hardware (automatic failover only
  helps if they do not share a host).
- Whether the database gets the offsite tier (`decisions/backup-tiers.md`).

## Steps

0. **Answer "Decide before step 1".** — gate: answers recorded in this plan.
1. **`pg-test` on a throwaway VM** (1 vCPU / 2 GB) plus the manager VM. Run
   the fio check first. — gate: Pigsty installs, dashboards show the node.
2. **Restore drill on `pg-test`.** pgBackRest to Garage; write test data,
   create a restore point, break something, restore to the point. — gate:
   journal entry with the restore.
3. **Alert drill.** Break WAL archiving on purpose (wrong bucket key) and
   confirm the alert arrives. — gate: alert seen, archiving fixed, `pg_wal`
   back to normal size.
4. **`pg-prod`** on its own VM with the snapshot rule for VMs (take an XO
   snapshot of the target first, `systems/xcp-ng.md`). — gate: security
   checklist above passes.
5. **First app.** Migrate one small app's database with `pg_dump`/`pg_restore`;
   the bundled database keeps running until the app works on the new one. —
   gate: the scratch-instance restore in "Done when".
6. **Remaining apps,** one at a time; record each in `inventory/services.md`.

## Links

`plans/migration.md`, `decisions/backup-tiers.md`, `systems/backups.md`,
`systems/openbao.md`, `ideas/multi-site-postgres.md`.
