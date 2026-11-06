# 2026-11-06 — installed Pigsty on pigsty-1

**Who:** the owner, with Claude Code  **Scope:** `pigsty-1`, a new B2 bucket, `kv/general/pigsty`  **Mode:** write
**Task:** step 1 of `plans/shared-postgres.md`  **Skill:** none

## What changed

- Pigsty v4.5.0 runs Postgres 18.6 as one cluster, `pg-meta`, on `pigsty-1`, with Patroni,
  etcd, PgBouncer, HAProxy and monitoring. The choices are in the plan's "Phase 1, as decided".
- `rpcbind` and `nfs-common` removed through `ansible/base.yml`. `fio` added for the disk check.
- Backups go to a new private B2 bucket, encrypted. Its key, the passphrase, Pigsty's
  generated passwords and its CA key and certificate are at `kv/general/pigsty`.
- `ansible/pigsty/` holds the config with placeholders and the script that renders it.

## Snapshot / backup taken

None: the machine held no data and rebuilds from `iac/oci/`.

## What went wrong

- The download script ran Pigsty's `bootstrap`, which replaced the apt sources. Restored from
  `/etc/apt/backup`. Setting `repo_remove: false` then made Pigsty's Ubuntu list clash with
  the original, which broke apt and stopped the first deploy. `repo_modules: infra,pgsql` fixed it.
- The second deploy failed when another `apt` process held the lock (PID 38462; what it was
  is not known). The third, unchanged, passed: `failed=0`.
- A debugging command printed HAProxy's admin password in the agent's session, so it was
  rotated in OpenBao and on the node. Another printed the generated password of Silo's backup
  user, which was removed and never used.

## How it was verified

- `patronictl list`: one leader, running. `show io_method`: `io_uring`. `data_checksums` and
  `ssl`: on. `shared_buffers`: 4485 MB.
- `pgbackrest info`: status ok, cipher `aes-256-cbc`, one full backup (44.8 MB, 5.2 MB stored).
  `pgbackrest check` passed. `pg_stat_archiver` showed 17 failures, all before the first
  backup finished, and a forced WAL switch archived with none added.
- Grafana answers 401 with no login. Ports 5433, 5434 and 5436 connect as `dbuser_meta`.
- A connection attempt from outside the tailnet to the node's public address found all 28 ports
  tried closed, including every Pigsty port listening on all interfaces.
- `fio`: `fdatasync` p99 1.89, 0.72 and 0.68 ms; etcd's target is under 10 ms.
- `ansible/pigsty/render.sh --check`: matches the node. The stored CA key pairs with its certificate
  (`openssl`).

## Restore drill

Step 2 of the plan, run the same day.

- Made a table of 100,000 rows in a scratch database, took its checksum, created a restore point,
  added 10 rows and dropped the table.
- `pgbackrest restore --type=name --target-action=promote` from B2 into a scratch folder, started
  on a private port, so the live cluster was not touched. The log says "recovery stopping at restore
  point". The table came back with the same count and checksum, and none of the 10 later rows.
- The restore took 127 s for 45 MB and 1,439 files. Recovery took 11 s more.
- The first attempt wrongly looked failed: the check ran while the copy was still replaying. Wait
  for `pg_is_in_recovery()` to be false. Its restore point is gone, as the next item explains.
- A second full backup expired the first (`retention_full: 1`), so nothing older can be restored from
  the visible backup. With the key that has no `deleteFiles`, expiry succeeded and only hid the files:
  98 MB of versions against 8 MB visible, until the 7-day lifecycle rule removes them.
- The scratch folder and database were removed. The leader is running.

## Alert drill

Step 3 of the plan, finished 2026-11-07.

- Set a wrong B2 key in `/etc/pgbackrest/pgbackrest.conf` and forced a WAL switch every 30 s.
- `PostgresArchiveFailing` fired after 7 minutes, with `pg_archiver_failed_count` up from 17 to 59, and
  the message reached the `pigsty-alerts` ntfy topic (read back through its API).
- Restored the key. Archiving resumed within 90 s with no new failures, `pgbackrest check` passed,
  and `pg_wal` stood at 753 MB. The alert stays active until the 10-minute window passes.
- Then set `pg_safeguard: true`, with the drill data gone.

## Other changes that day

- `trusted=yes` removed from Pigsty's apt lists; keys are pinned (`ansible/pigsty/patch-node.sh`).
- New ntfy user `pigsty-publisher`, write-only on `pigsty-alerts`. Its token is at `kv/general/ntfy`.
- User and database `blinko`, for the test app. A login and a write worked from a container on the
  Dokploy host, through port 5433.

## Still open

- The proxy on Dokploy, the database UIs and the wildcard certificate are not started.
- No alert for a backup that stops running; the new rule covers only WAL archiving.
- Adding Garage as a second pgBackRest repository: untested.
