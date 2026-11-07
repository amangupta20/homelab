# 2026-11-07 — restore test: one database copied out of a restored cluster

**Who:** the owner, with Claude Code  **Scope:** a scratch instance on `pigsty-1`, then a throwaway ARM64 container on the owner's workstation; a temporary marker table in `blinko`  **Mode:** write
**Task:** prove the rollback in `plans/shared-postgres.md`, "Restores cover the whole server" (owner, 2026-11-07)  **Skill:** none

Two runs. The first was on `pigsty-1`, which the agent chose without asking; the owner expected the workstation. That run
used the node's own config and could not show recovery after losing the node, so the second run did. Most of the steps and
results below are from the first run; "Second run" says what differed.

## What changed

Nothing lasting. The live cluster briefly held a marker table in `blinko` and a database `blinko_restore_drill`; both were
dropped. Blinko kept running on `blinko`, which was not replaced. WAL archiving went on as usual.

## Snapshot / backup taken

None taken. The restore used the newest backup on B2 (daily incremental, 01:00 that day) and WAL up to the restore point.

## The steps

1. Created `monitor.restore_drill_marker` in `blinko` with a row `before`, and took a checksum of each table in `public` and `pgboss`.
2. Created a named restore point, added a row `after`, and switched WAL until the file was archived.
3. `pgbackrest --stanza=pg-meta --pg1-path=<scratch> --type=name --target=<name> --target-action=promote --archive-mode=off restore`
4. Before starting it, appended overrides to the scratch `postgresql.auto.conf` and replaced its `pg_hba.conf` with `local all all peer`.
   The restored config would otherwise use the live cluster's `hba_file` and `ident_file`, its `archive_command` and `pg_cron`:

   ```
   port = 55432
   listen_addresses = ''
   unix_socket_directories = '<scratch>/sock'
   hba_file = '<scratch>/pg_hba.conf'
   ident_file = '<scratch>/pg_ident.conf'
   archive_mode = off
   archive_command = ''
   shared_preload_libraries = ''
   shared_buffers = '256MB'
   huge_pages = off
   ssl = off
   cluster_name = 'blinko-drill'
   log_directory = 'drill-log'
   ```

5. Started it with `pg_ctl`, checked `show data_directory`, and waited for `pg_is_in_recovery()` to be false.
6. `pg_dump -Fc -d blinko` from the scratch instance. On the live cluster, `CREATE DATABASE ... OWNER blinko TEMPLATE template0
   ENCODING 'UTF8' LOCALE 'C.UTF-8'`, then `REVOKE CONNECT ... FROM PUBLIC`, then `pg_restore --single-transaction --exit-on-error`.
7. Database-level grants are not in a plain dump. They came from the `GRANT`, `REVOKE` and `ALTER DATABASE` lines of
   `pg_dump -C -s`, with the database name changed.

## How it was verified

- **The point in time:** the scratch instance and the copy held only `before`, while live held `before` and `after`. The log says
  "recovery stopping at restore point".
- **Live against restored:** every table's row count and md5 matched, in `public` and `pgboss`. Of 50 tables and sequences, only four
  sequences differed, each 32 higher on the restore. Postgres logs sequences ahead of use, as recalled, so numbers are skipped, not reused.
- **Restored against the copy:** all 50 matched, sequences too, and `pg_dump -s` output (7,674 lines) had no differences.
- **Grants:** `datacl` holds the same entries in a different order. Extension names are in the matching schema dumps, and `blinko`'s
  extensions are all at the default version (the script's own check said "no", because it compared them in no fixed order).
- **The app's role:** `SET ROLE blinko` read `accounts`, `notes` and `_prisma_migrations`, and a rolled-back update worked.
- **Timing:** 112 s to restore 58.8 MB and 1,900 files from B2, 67 s of recovery, about 1 s for the copy, 181 s in all.
- **Afterwards:** no timeline history file in the repository, `failed_count` stayed at 59, `pgbackrest check` passed,
  the Patroni leader is running, Blinko's container is healthy and `blinko` still has its 7 notes.

## Second run: on the workstation, without the node's config

- **Why a container:** the workstation is x86_64 and `pigsty-1` is ARM64, and Postgres data files are not officially portable between
  architectures. The restore ran in `podman run --arch arm64` under `qemu-user-static`, on `postgres:18.6`, with PGDG's
  `pgbackrest` 2.60 and `postgresql-18-repack` 1.5.3, the same versions as the node.
- **What it needed:** B2's key, its bucket and the passphrase from `kv/general/pigsty`, and the other repository settings from
  `ansible/pigsty/pigsty.yml.template`. Nothing came from the node's files. The config sat on a tmpfs in the container.
- **Packages a bare image lacks:** `ca-certificates`, or pgBackRest stops with `[CryptoError] unable to verify certificate`, which reads
  like a wrong passphrase. `postgresql-18-repack` too, or `pg_restore` cannot create that extension.
- **Overrides added to the list above:** `io_method = 'sync'` (the node's is `io_uring`), `autovacuum = off`, and empty
  `session_preload_libraries` and `local_preload_libraries`.
- **The live cluster's part:** only the marker table, the restore point and the checksums to compare with.

| Check | Result |
|---|---|
| Point in time | the restore and the copy held only `before`; "recovery stopping at restore point" in the log |
| Live against restored | every table matched; of 50 tables and sequences, only the same four sequences differed |
| Restored against the copy | all 50 matched; `pg_dump -s` (7,674 lines) had no differences |
| Grants and extensions | `datacl` the same set; extension names and versions the same as live |
| The app's role | read `accounts`, `notes` and `_prisma_migrations`; a rolled-back update worked |
| Timing | 133 s to restore, 244 s to start and recover under emulation, 2 s to copy, 395 s in all |
| Afterwards | no timeline history file in the repository, `failed_count` still 59, `pgbackrest check` passed |

The scratch folder reached 2.4 GB for a 59 MB restore, so allow far more disk than the backup's size (`du`; what took the rest was
not looked at). The container and image were deleted.

## What went wrong

First run: the script's cleanup tested for `postmaster.pid` as a user who cannot read the scratch folder, so it skipped the stop and deleted the
folder under the running scratch instance. Its "scratch left: 0" was false comfort for the same reason. A socket check showed it, and
SIGINT to that instance's postmaster stopped it. It only had a socket, with archiving off, so the live cluster was not affected.
Run these checks through `sudo`.

## Still open

- Under emulation only: a restore on a real ARM64 machine other than `pigsty-1` has not been run.
- Blinko has not run on a copy: PgBouncer lists databases by name, so the copy on `pigsty-1` was not reachable through port 5433, and the workstation's copy had no app pointed at it.
- The swap itself is untested: stopping the app, renaming the databases and starting it again.
- Blinko's uploads are not in this restore (`apps/vps/blinko/README.md`).
- The plan's "Done when" still needs this restore for a migrated app. Blinko is a new test app.
