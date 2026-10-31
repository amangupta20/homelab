---
name: back-up-a-service
description: Use when giving a service its backups, adding the encrypted offsite (B2) tier to a service, or checking that a service's backups follow the two-tier pattern — choosing how to capture its data, sending it to Garage and optionally offsite, setting retention, and proving it with a restore test.
---

# Back up a service (two tiers)

**Status:** UNTESTED — the pattern is proposed in `decisions/backup-tiers.md`
and no service has been taken through this runbook yet.
**Touches:** writes to the service's host (a backup job), Garage, and B2.

## When to use / when not to

Use it for a new service with state, when the owner adds a service to tier 2,
or to bring an old backup in line with the pattern.

Not for VM images (Xen Orchestra handles those, `systems/backups.md`) and not
for deciding *which* services get tier 2: that is the owner's call, recorded in
`decisions/backup-tiers.md`.

## Before you start

- Read the service's `systems/` page and its row in `systems/backups.md`.
- Know which tier it gets. Tier 2 only if the owner named it.
- For tier 2: a B2 bucket, a key limited to that bucket, and the encryption
  password — all in OpenBao, and the password also kept outside the lab by the
  owner (`decisions/backup-tiers.md`, rule 2). Missing any of these: stop and
  ask.
- Never write a credential into a command you show, a file in this repo or a
  log. Read them from OpenBao at run time (`systems/openbao.md`, "Daily use").

## Steps

1. **Pick how to capture the data**, by what kind of data it is. Copying a live
   database's files gives a broken copy.

   | Data | Capture with | Notes |
   |---|---|---|
   | Postgres (shared server) | pgBackRest: `repo1` Garage, `repo2` B2 | `plans/shared-postgres.md`, "Backups" |
   | Postgres or MySQL bundled in a stack | `pg_dump` / `mysqldump` | dump, then back up the dump |
   | OpenBao | Raft snapshot through OpenBao's API | already done for tier 1 (`apps/vps/openbao/README.md`) |
   | SQLite | `sqlite3 <db> ".backup <file>"` | safe while the app runs |
   | Plain files and volumes | Dokploy volume backup (tier 1), restic (tier 2) | stop the app first if it writes constantly |

2. **Tier 1 — Garage.** Dokploy apps: add or check the backup in Dokploy with
   destination `garage`. Anything else: a scheduled job that uploads to the
   Garage bucket. Keep many versions (OpenBao keeps 14). — expect: the first
   object listed in the bucket.

3. **Tier 2 — B2, from the source** (only if the owner named the service).
   With restic (**UNTESTED**; placeholders in angle brackets):

   ```bash
   # credentials come from OpenBao, exported for this shell only
   export AWS_ACCESS_KEY_ID=<from OpenBao>
   export AWS_SECRET_ACCESS_KEY=<from OpenBao>
   export RESTIC_PASSWORD=<from OpenBao>
   export RESTIC_REPOSITORY="s3:https://<b2-s3-endpoint>/<bucket>/<service>"

   restic init                                        # once per service
   <capture command> | restic backup --stdin --stdin-filename <service>.<ext> --tag <service>
   restic forget --keep-daily 3 --keep-weekly 1 --keep-monthly 1 --prune
   ```

   `--stdin` streams the capture straight into restic, so no unencrypted copy
   is left on disk. For pgBackRest, set `repo2-type=s3`, the B2 endpoint and
   bucket, `repo2-cipher-type=aes-256-cbc` and a smaller
   `repo2-retention-full` instead. — expect: `restic snapshots` lists one
   snapshot.

4. **Schedule it** next to the tier-1 job (same scheduler, so one place shows
   both), and make a failed run reach ntfy or the job log someone reads.

5. **Check the B2 bucket:** a lifecycle rule keeps only the current version
   (otherwise deletes only hide files), and deletion protection is set as
   `decisions/backup-tiers.md` rule 3 describes.

## Verify

A restore from **each** tier into a throwaway place, never over the live
service:

```bash
restic snapshots --tag <service>
restic restore latest --tag <service> --target <empty scratch dir>
restic check
```

Then load the restored data into a throwaway instance of the service (for
OpenBao, the method in `journal/2026-10-29-restore-test-openbao.md`) and check
real data is there.

## Stop if

- The only copy of the encryption password is inside the lab.
- The capture needs a service stopped and there is no agreed window.
- A restore fails or the restored data is incomplete: the backup does not
  count; record what you saw and ask the owner.
- A step would delete or overwrite an existing backup (`decisions/agent-access.md`).

## Afterwards

- Update the service's line in `systems/backups.md` with both tiers, and tick
  its restore under "Tested restores" only after the restore worked.
- Write `journal/YYYY-MM-DD-backup-<service>.md`.
- If a step here was wrong, propose the fix (`skills/write-a-skill/`).
