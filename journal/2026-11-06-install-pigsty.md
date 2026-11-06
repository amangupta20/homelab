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

## Still open

- No restore tested, so the backup does not count yet (`systems/backups.md`). Step 2 of the plan.
- Alerts to ntfy, the WAL archiving alert, the proxy on Dokploy, the database UIs and the wildcard
  certificate are not started.
- `pgBackRest` expiring a backup with a key that cannot delete, and adding Garage as a second
  repository: both untested.
