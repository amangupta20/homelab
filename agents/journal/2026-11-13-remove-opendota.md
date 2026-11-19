# 2026-11-13 — removed the opendota stack from the VPS

**Who:** the owner, with Claude Code  **Scope:** Dokploy project `opendota` on the Remote VPS  **Mode:** write
**Task:** the owner asked to back up the stack's Compose file and variables, then delete it with its volumes  **Skill:** none

## What changed

- The Compose service `opendota` deleted with its four volumes (Postgres, Cassandra, Redis, MinIO) through Dokploy's API
  (`compose.delete` with `deleteVolumes`), then the empty project (`project.remove`). It was not running: Dokploy showed it as idle
  and it had no containers (`docker ps -a`).
- The data in the volumes is gone on purpose (owner, 2026-11-13). It was not backed up.
- Row removed from `inventory/services.md`.

## Snapshot / backup taken

The Compose file and the three environment variables, as Dokploy stored them, are in OpenBao at `kv/dokploy/opendota` (fields
`compose_file` and `env`). Both were read back and their SHA-256 sums matched the originals before anything was deleted. That is
enough to create the stack again empty; it is not a backup of its data.

## How it was verified

- No container, volume or folder under `/etc/dokploy/compose` with `dota` in its name is left on the VPS, and Dokploy's project list
  has no `opendota`.
- Used space on `/` went from 132 GB to 98 GB (`df`, before the delete and after Docker finished removing the volumes).

## Still open

- Recreating the stack from the saved Compose file has not been tried.
