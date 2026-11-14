---
type: plan
status: "in progress (installed on pigsty-1; drills done; Blinko running as a test)"
verified: "partly (pigsty-1 read over SSH and Pigsty's docs read 2026-11-06; the rest is design from research 2026-10-31)"
hosts:
  - pigsty-1
  - XCP-ng host
  - TrueNAS VM
  - Remote VPS
tags:
  - plan
  - postgres
  - database
  - pigsty
---

# Shared Postgres

**Status:** in progress. Pigsty runs on `pigsty-1` since 2026-11-06
(`journal/2026-11-06-install-pigsty.md`). The restore and alert drills passed, and Blinko runs on it as a test
(`journal/2026-11-07-deploy-blinko.md`). No app has migrated to it.
Part of the migration (`plans/home-overhaul.md`), and comes before it: each app's
database target shapes how it is migrated. The owner chose the topology on
2026-11-01 ("Topology", below) and how phase 1 starts on 2026-11-06 ("Phase 1,
as decided"). The app questions wait until step 5 ("Decide before step 5").
**Goal:** one Postgres cluster, set up with Pigsty, that apps share
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

## Topology (owner, 2026-11-01)

Two Postgres nodes on separate hardware and a third etcd member as a
tiebreaker, built in two phases:

| Phase | Postgres | etcd | When |
|---|---|---|---|
| 1 | one node on a second VPS (primary) | one member, on the second VPS (owner, 2026-11-01) | once the second VPS exists ("soon", owner) |
| 2 | adds a node in a home VM, as a replica | three members: second VPS, home VM, and a tiebreaker on the Remote VPS (the Dokploy host), added when the home node starts (owner, 2026-11-01) | after the homelab is cleaned up a bit (owner) |

- **Where the primary normally lives is not decided.** It starts on the
  second VPS because that is the only node; once the home node has caught up,
  it may move home. The owner expects that to be an easy change: a planned
  `patronictl switchover` waits for the replica to catch up, and apps that
  connect through Pigsty's HAProxy follow the new primary on their own,
  because HAProxy health-checks Patroni (as recalled — check). What does
  change is which apps pay a round trip per query: with the primary on the
  VPS, home apps do; with it at home, VPS apps do.
- **Latency:** home to VPS is below 50 ms (owner's estimate, not measured).
  That sits in the "defaults usually fine" row under "Network latency";
  jitter is the real test, so measure with `mtr` over hours before phase 2.
- **This replaces the rule "every etcd member sits on the home LAN"** that
  this plan had, and goes against the reasoning in
  `ideas/multi-site-postgres.md` ("Why etcd must not span home and the VPS").
  What it means, from that reasoning:
  - Home internet down: home holds one of three etcd members, so the home
    node cannot be primary. If the primary is at home, Patroni demotes it and
    promotes the VPS node; home apps lose their database until the link is
    back. With asynchronous replication, the last few seconds of writes can
    be lost in that failover.
  - Remote VPS or second VPS down: two of three remain; the cluster keeps
    working.
  - Jitter on the home link can trigger false elections; tune the heartbeat
    and election timeout from measured round trips.
- **Why one etcd member in phase 1:** a two-member etcd is weaker than one —
  losing either member loses the majority and stops the primary. So phase 1
  runs one member, and the tiebreaker arrives together with the home member
  (owner, 2026-11-01).
- **Going from one member to three passes through two.** etcd adds members
  one at a time (`etcdctl member add`, then start the new member joining the
  existing cluster — as recalled, check Pigsty's own command for it). Between
  the second and the third joining, losing either running member stops the
  primary. Add both in one quiet window, check `etcdctl endpoint health` on
  all three, and only then add the home Postgres replica.
- **Two of the three etcd members would sit with one provider.** If the second
  VPS is also on Oracle Cloud, the Remote VPS and the second VPS together
  hold the majority. An Oracle region outage, or a problem with the account
  (billing, a reclaimed Always Free instance), can take both at once and leave
  home with one of three: no primary anywhere, even though the home node is
  healthy. Check whether the second VPS is a separate account or region, or
  accept this as the known shared risk.
- **Tailscale carries etcd, Patroni and replication,** so a node whose
  Tailscale key expires drops out of the cluster. Turn off key expiry for the
  database and etcd nodes in the Tailscale admin console, or tag them so their
  keys do not expire. Existing connections survive an outage of Tailscale's
  coordination server; new ones do not (as recalled — check).
- **Phase 1 has no failover at all:** one node, so backups are the only
  protection. With Garage at home not available yet, phase 1 needs
  pgBackRest's offsite repository from day one ("Backups").
- **The Dokploy host gains a role.** It already runs OpenBao, which will hold
  Pigsty's passwords; with the tiebreaker it also counts towards the
  database's quorum. Not a loop, but one more reason that host matters.

Open for this topology (also in `decisions/open-questions.md`):

- How the tiebreaker runs on the Dokploy host: a Pigsty-managed etcd
  installed on the host over SSH, or a container under Dokploy outside
  Pigsty's control.
- Where Pigsty's manager lives once the home VM exists: stay on `pigsty-1` or move.
- ~~pgBackRest's first repository~~ — answered 2026-11-06: B2, with Garage added
  when home is back ("Backups").

## Phase 1, as decided (owner, 2026-11-06)

- **One node only until the lab is up:** one Postgres cluster on `pigsty-1`.
  When the lab is back, a second node goes in the lab, and an etcd tiebreaker
  goes on the Dokploy host ("or something", owner; how it runs is still open).
  So there is no throwaway `pg-test` VM. The drills in steps 2 and 3 run on this
  cluster before any app data reaches it (agent's reading of "one node only").
- **The offsite tier comes first.** Backblaze B2 is in place before Garage, the
  reverse of the usual order in `decisions/backup-tiers.md`, because Garage at
  home is not available yet ("Backups").
- **Few versions on B2** ("not too many", owner). The numbers are in "Backups".
- **The app questions can wait** ("Decide before step 5").
- **Template:** Pigsty's `rich`, without its Silo object store, Redis and Docker apps.
  Standard Postgres 18, `oltp` tuning, `C.UTF-8` locale, the node's Tailscale address
  as its Pigsty address, and Pigsty's firewall management off.
- **Database UIs:** CloudBeaver and pgAdmin on Dokploy, not on this node. The owner
  drops whichever gets used less. Tailnet only, through `pg-proxy:5436` as `dbuser_owner`, a
  non-superuser member of each app's role (`apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`; owner,
  2026-11-09).
- **Certificates:** Pigsty's own CA first, then a wildcard Let's Encrypt certificate
  over DNS-01 at the proxy. Traefik's `cloudflare` resolver does this since 2026-11-09 (`systems/vps.md`,
  "Certificates"). Pigsty's certbot needs public DNS and a public port 80
  (`pigsty.io/docs/infra/admin/cert`), which this node does not have.
- **Proxy:** a small HAProxy container on Dokploy right after the install, so apps
  there use one address: `pg-proxy:5432`, defined in `apps/vps/pg-proxy/`. Containers reach the
  tailnet through the host (Blinko connects to pigsty-1's tailnet address, 2026-11-07), but cannot
  resolve tailnet names, so addresses come from the environment (2026-11-09).
- **Alerts:** ntfy, the owner's preference, through ntfy's built-in `alertmanager`
  template, on topic `pigsty-alerts`. A user that can only write to that topic has the token.
  A test alert arrived on 2026-11-06. Pigsty has no setting for this, so `render.sh` edits its
  template. `patch-node.sh` adds rules for failed WAL archiving and for backups that stop, which Pigsty does not ship
  (`journal/2026-11-07-backup-age-alerts.md`).
- **TLS:** on where a client asks for it: Postgres by default, PgBouncer with `prefer`.
  `pgbench` (16 clients, on the node itself, 2026-11-06) showed about 10% fewer
  transactions a second and 1 ms more latency, which the owner's rule accepts. Opening a new
  TLS connection costs far more (about 4 times slower through PgBouncer), so apps should
  keep connections open. Patroni's stays off, because the proxy's health checks use that API.
  Monitoring keeps metrics 30 days and logs 30 days or 20 GB.
- **MySQL apps keep their own database in compose:** Pigsty runs one instance per node,
  and its MySQL module refuses Ubuntu on ARM64 (`pigsty.io/docs/mysql`). Redis also stays
  in compose: a cache should sit next to its app.
- **Pigsty's manager runs on `pigsty-1`** (agent's recommendation: it is the only
  node). Dashboards stay on the tailnet (the "Security checklist").

### What the node and Pigsty's docs say (2026-11-06)

- **Support:** Pigsty v4.5.0 lists Ubuntu 24.04 on aarch64 as supported, and
  Ubuntu 24.04.4 as a recommended version (`pigsty.io/docs/ref/linux`; the release
  notes list ARM64 in the validated baseline). Not run here yet. `pigsty-1` is
  Ubuntu 24.04.5 on aarch64 with 3 CPUs and 17 GiB of memory (`uname -m`,
  `/etc/os-release`, `nproc`, `free -h` over SSH).
- **Disk:** one 150 GB ext4 root disk and no separate `/data` (`df -hT`). Pigsty's
  docs recommend a `/data` mount point on xfs (`pigsty.io/docs/deploy/prepare`);
  the `fio` check below passes on root. Three runs on 2026-11-06 gave `fdatasync` p99
  of 1.89, 0.72 and 0.68 ms, against etcd's target of under 10 ms.
- **SSH to itself:** set up 2026-11-06 with a key made on the node; `configure`
  reports both `127.0.0.1` and the node's address as ok. Sudo already worked.
- **Install commands,** run 2026-11-06. `install.yml`, named in the release notes, does
  not exist in v4.5.0. To rebuild, use `ansible/pigsty/` instead of hand edits:

  ```bash
  curl -fsSL https://repo.pigsty.io/get | bash -s v4.5.0
  cd ~/pigsty
  ./configure -c rich -g -i <the node's Tailscale address> -n
  ./deploy.yml
  ```

- **`bootstrap` replaces the apt sources.** The download script runs it. It moved
  the Ubuntu and Tailscale sources to `/etc/apt/backup` and wrote its own `sources.list`. The
  originals were restored on 2026-11-06. `repo_remove: false`, `node_repo_remove: false` and
  `repo_modules: infra,pgsql` stop the deploy doing the same; `./bootstrap --keep` is
  documented in the script for next time (not run). `ansible/pigsty/patch-node.sh` removed
  `trusted=yes`, which turned off signature checks, from Pigsty's apt lists: each publisher's key
  is pinned instead. Only the local repo keeps it, as it has no signature. `apt-get update` is
  clean, and a rerun of Pigsty's repo tasks kept the lists.
- **`configure` changes things to review:** below 4 CPUs it picks the `tiny` tuning,
  overridden here to `oltp` (owner). Anonymous Grafana is hard-coded on in
  `roles/infra/templates/grafana/grafana.ini.j2`, not a parameter as the docs suggest, so
  that line is edited on the node, and an upgrade would need it again.
- **Node DNS stays as it is:** `node_dns_method: none`, so Pigsty does not edit
  `resolv.conf`, which Tailscale and systemd-resolved manage. Its dnsmasq binds only
  `127.0.0.1` and the node's address (its template), so it should not clash with
  systemd-resolved.
- **Passwords:** Pigsty's defaults are public. `./configure -g` generates random
  ones but not pgBackRest's `cipher_pass`, or credentials added by hand
  (`pigsty.io/docs/setup/install`). The generated ones are at `kv/general/pigsty`.
- **Read the generated config against the "Security checklist" before deploying.**
  Pigsty's docs say its base config opens ports 80 and 443 publicly and allows
  anonymous read access to Grafana (`pigsty.io/docs/setup/security`), and they do
  not mention Tailscale. What its firewall settings do to Oracle's iptables rules
  (`ansible/base.yml`) is unknown.

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
- **etcd spans sites in this plan** (owner, 2026-11-01; "Topology", above).
  Earlier this plan kept every member on the home LAN, because a member on the
  VPS makes the home primary depend on the home internet connection
  (`ideas/multi-site-postgres.md`, "Why etcd must not span home and the VPS").
- **Apps:** a query from an app to a database over the internet pays one round
  trip each time; apps that send many small queries feel it most. Keep each
  app on the same LAN as the database it writes to.
- **Watch it:** etcd reports both kinds of latency as
  `etcd_network_peer_round_trip_time_seconds` and
  `etcd_disk_wal_fsync_duration_seconds`; Pigsty's dashboards graph them.

## Backups

Follows `decisions/backup-tiers.md` (proposed).

- **pgBackRest, B2 first** (owner, 2026-11-06): encrypted offsite (tier 2) is the
  only repository until Garage is back, and Garage (tier 1) is added then.
  **UNTESTED.** Pigsty v4.5.0 writes only the repository `pgbackrest_method`
  selects, as `repo1` (`pigsty.io/docs/pgsql/backup/repository`), so B2 becomes
  `repo1`, not the `repo2` that `skills/back-up-a-service/` names. An S3 repository
  with no local one is not stated as supported in those docs; adding the second
  repository later may need raw pgBackRest options.
- **How many on B2 (owner, 2026-11-06):** one. A weekly full backup with daily
  incrementals, `retention_full_type: count` and `retention_full: 1`, because Garage
  follows once the lab is up, expected about a week later (owner). So the oldest
  restore point is only 0 to 7 days back. This does not match the "3 daily, 1 weekly,
  1 monthly" in `decisions/backup-tiers.md`, which pgBackRest cannot express. Garage
  keeps 3. Size against B2's 10 GB free tier is not measured.
- **Point-in-time restore:** a base backup plus the WAL (write-ahead log, the
  record of every change) archived after it lets you restore to any second
  in between, or to a named point (`SELECT pg_create_restore_point('before-x');`).
- **Retention by days, for Garage later:** `retention_full_type: time`. Data older
  than the window remains until the next full backup ages out: oldest kept ≈
  window + time between full backups.
- **`archive_timeout = 300` by default (owner, 2026-11-09)**, so a quiet database
  still ships its changes at least every 5 minutes; 600 is also acceptable. Lowered
  only when an app's usage needs a smaller loss window. 300 is what Pigsty's `oltp`
  template sets and what runs on `pigsty-1` (`pg_settings`, 2026-11-07). The setting
  covers the whole server, not one database: a busy app fills 16 MB WAL segments and
  ships them sooner anyway, and one app that needs less than 5 minutes means lowering
  it for every database or giving that app its own cluster.
- **Restores cover the whole server, not one database.** To roll back one
  app, restore to a scratch instance and copy that app's database across.
  Tried on 2026-11-07, without swapping the app onto the copy (`journal/2026-11-07-restore-test-blinko-copy.md`).

Failure to watch: if archiving fails (offsite down, expired key, full bucket),
Postgres keeps every WAL file locally until the disk fills and Postgres stops.
A replication slot left behind by a removed replica does the same; cap slots
with `max_slot_wal_keep_size`. Alert on archive failures and on `pg_wal` size.

## Security checklist

- Listens on the LAN or tailnet only, never a public address.
- One `pg_hba` rule for the tailnet range with a password required (owner,
  2026-11-06). Per-source rules add little: containers on one host are expected to
  share its Tailscale address (not checked). Tailnet access rules choose the machines.
  PgBouncer has its own list, so `pgb_hba_rules` needs the same rule; without it, logins
  over the tailnet failed with "no authentication method is found".
- One role and one database per app; `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC`
  for every database; no app gets superuser. Extensions an app needs are
  created by the admin.
- Minor versions kept current: privilege-escalation bugs would turn one app's
  password into every app's data.
- App passwords in OpenBao.
- Dashboards (Grafana) on the LAN or tailnet only, default admin password
  changed before first use.

## Extensions that need more than `CREATE EXTENSION`

Tested in a scratch database 2026-11-06. `pg_cron` can only be created in the `postgres`
database. `vchord`, `pg_search` and `pg_duckdb` are installed but must be added to `pg_libs`
first, which restarts Postgres. The rest of the list in `ansible/pigsty/` created normally.

## Adding an app

1. Create its role and database, plus any extension it needs (as admin).
2. Store the password in OpenBao.
3. Remove the bundled database from its compose file and point it at `pg-proxy:5432`
   (`apps/vps/pg-proxy/README.md`).
4. Add its `pg_hba.conf` line, and its role to `dbuser_owner`'s `roles` so the database
   UIs can open it (`apps/vps/pgadmin/README.md`).
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

## Decide before step 5 (owner)

Moved from "before step 1" on 2026-11-06 (owner): steps 1 to 4 hold no app data.

- Which apps move to the shared server first, and which stay bundled.
- Where apps that run on the VPS get their database: from this server over the
  tailnet (a round trip per query), or bundled as today.
- ~~One home database node, or two on separate hardware~~ — answered
  2026-11-01: two nodes on separate hardware (a second VPS first, a home VM
  later) and an etcd tiebreaker on the Remote VPS ("Topology").
- Where the primary normally lives once both nodes exist (home or the second
  VPS).
- ~~Whether the database gets the offsite tier~~ — answered 2026-11-06: yes, and
  before Garage ("Phase 1, as decided").

## B2 for pgBackRest (done 2026-11-06)

The bucket, its key and the encryption passphrase are at `kv/general/pigsty`. The
owner created the first two; the passphrase is in OpenBao only, by the owner's choice
(`decisions/backup-tiers.md`, rule 2).

The key has `listBuckets`, `listFiles`, `readFiles` and `writeFiles`, for one private
bucket, with a lifecycle rule that removes hidden files after 7 days (read through B2's
API). This is how it meets rule 3 of that decision. Tested with a throwaway object through
the S3 API (virtual-hosted addressing): upload, multipart upload and abort work; a delete by
name only hides the file; a delete of a specific version gets `AccessDenied`. On 2026-11-06 a full backup, WAL archiving, a restore and expiry all worked
with this key. Expiry only hid the files, as intended (`journal/2026-11-06-install-pigsty.md`).

B2 requests (2026-11-07): one `pgbackrest info` is 4 class C and 2 class B (trace log), and Pigsty's exporter
runs it every 120 s. A restore reads about one file per class B request. The owner added a card and kept
the polling, as Backblaze lists these calls as free for pay-as-you-go accounts (pricing page; not yet checked
against a bill).

## Steps

1. **Install on `pigsty-1`,** phase 1 of "Topology". (Done 2026-11-06.)
   Run the `fio` check first. — gate: Pigsty installs, dashboards show the node,
   the "Security checklist" passes, and `pgbackrest info` lists the B2 repository.
2. **Restore drill.** (Done 2026-11-06.) Back up to B2; write test data, create a restore point, break
   something, restore to the point. — gate: journal entry with the restore.
3. **Alert drill.** (Done 2026-11-07.) Break WAL archiving on purpose (wrong bucket key) and
   confirm the alert arrives. — gate: alert seen, archiving fixed, `pg_wal`
   back to normal size.
4. **Clean up the drills.** (Done 2026-11-07; `pg_safeguard` on.) Drop the test data, so the cluster is ready for real
   data. Oracle has no XO snapshot; the node rebuilds from `iac/oci/` and backups.
   — gate: the "Security checklist" passes again.
5. **First app.** Blinko first, as a test with nothing to lose (`apps/vps/blinko/`, owner, 2026-11-06). Then answer "Decide before step 5". Migrate one small app's database
   with `pg_dump`/`pg_restore`; the bundled database keeps running until the app
   works on the new one. — gate: the scratch-instance restore in "Done when".
6. **Remaining apps,** one at a time; record each in `inventory/services.md`.
7. **When the lab is up:** Garage as a second repository, then phase 2 of
   "Topology". XCP-ng's snapshot rule applies to the home node
   (`systems/xcp-ng.md`). — gate: a restore from Garage is recorded.

## Links

`plans/home-overhaul.md`, `decisions/backup-tiers.md`, `systems/backups.md`,
`systems/openbao.md`, `ideas/multi-site-postgres.md`.
