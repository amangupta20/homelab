# 2026-11-07 — added alerts for pgBackRest backups that stop

**Who:** the owner, with Claude Code  **Scope:** `vmalert` rules and a drill on `pigsty-1`  **Mode:** write
**Task:** next step 2 of the Pigsty handoff; the gap is in `decisions/open-questions.md`  **Skill:** none

## What changed

`/infra/rules/pg-backup.yml`, written by `ansible/pigsty/patch-node.sh`, so it survives an infra rerun. All four
rules go to the `pigsty-alerts` ntfy topic:

| Alert | Fires when | Why this value |
|---|---|---|
| `PgBackRestBackupStale` | no backup of any type for 30 h, for 10 min | backups run daily |
| `PgBackRestFullBackupStale` | no full backup for 8 days, for 10 min | full backups run weekly |
| `PgBackRestRepoUnhealthy` | `pgbackrest_stanza_status` is not 0, for 15 min | the exporter polls every 120 s; rides out a short B2 error (guess) |
| `PgBackRestExporterMissing` | `pgbackrest_stanza_status` is absent, for 15 min | Pigsty's `AgentDown` skips the `pgsql` job |

## Snapshot / backup taken

None taken: only a rule file and the exporter changed, not data. The newest backup was from 01:00 that day.

## What was found

With a fake B2 key given to the exporter alone (a systemd `Environment=` line, which overrides pgBackRest's config
for that process), `pgbackrest_backup_since_last_completion_seconds` disappeared, `pgbackrest_exporter_status` stayed
1, and `pgbackrest_stanza_status` went to 99 under `stanza="[invalid]"`. A rule on backup age alone would have
stayed quiet. The `incr` series counts every backup type: with no differential backups on record, `diff` read the same
as `full`, and `incr` was newer.

## How it was verified

- `vmalert`'s `/api/v1/rules` lists the four rules with health `ok`, and none fired on the healthy cluster.
- Drill: temporary copies of the rules, with the same expressions except a 60 s age threshold, and waits of 30 s to 1 min.
  `DRILLBackupAge` fired on the live metric, `DRILLRepoUnhealthy` with the fake key and `DRILLExporterMissing` with the
  exporter stopped. All three messages were read back through ntfy's API, and Alertmanager's log showed no notify errors.
- During the drill the real `PgBackRestRepoUnhealthy` and `PgBackRestExporterMissing` went to `pending`, then cleared.
- WAL archiving kept working: `failed_count` stayed at 59, and `archived_count` rose. The drill files were removed,
  the exporter is active, `pgbackrest_stanza_status` is 0, and no alerts are active.

## Still open

- The 30 h and 8 day rules have not fired with their real thresholds. Their expressions were only run with lower ones.
- `pgbackrest_stanza_status` during a running backup was not watched. `for: 15m` may not outlast a long full backup
  if it turns non-zero then; as recalled it stays 0, unverified.
- These rules run on `pigsty-1`, so they stay silent if that node or its monitoring stops. Nothing outside it checks.
