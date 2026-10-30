# 2026-10-29 — tested restore of OpenBao from Raft snapshot

**Who:** the owner, with Antigravity  **Scope:** remote VPS, Dokploy schedule `openbao-raft-snapshot`, workstation restore test  **Mode:** write
**Task:** complete restore test gate for step 2 of `plans/vps-foundations.md`  **Skill:** none

## What changed

- Configured a scheduled task in Dokploy (`openbao-raft-snapshot`, cron `0 2 * * *`, timezone `Asia/Kolkata`, type `dokploy-server`).
- The task script runs daily to:
  1. Renew the OpenBao snapshot token and Dokploy's OpenBao provider token (`/v1/auth/token/renew-self`).
  2. Take a point-in-time Raft snapshot via OpenBao HTTP API (`/v1/sys/storage/raft/snapshot`) without restarting or resealing OpenBao.
  3. Upload the snapshot directly to Garage S3 (`s3://dockploy/openbao/openbao-<timestamp>.snap`) using an ephemeral `amazon/aws-cli` container mounting only the isolated `/tmp/openbao-backup` directory read-only.
  4. Automatically prune older snapshots to retain the 14 most recent copies.
- Tested live manual execution of the schedule: created `openbao-20261029-172211.snap` (46,617 bytes) and uploaded to Garage.
- Verified restore on the workstation:
  - Downloaded `openbao-20261029-172211.snap` from Garage S3 to `/tmp/baorestore/`.
  - Started a clean throwaway OpenBao 2.7.1 container (`podman run --name baorestore ...`).
  - Initialized with throwaway credentials, unsealed, and executed `bao operator raft snapshot restore -force openbao.snap`.
  - The instance adopted the exact cluster state, sealed with threshold 2 of 3.
  - Enabled Web UI (`https://127.0.0.1:18200/ui/`), where the owner entered 2 real unseal keys, logged in as the owner, and verified that secrets and configuration matched the live cluster.
  - Tore down and deleted the test container and temporary files.

## Snapshot / backup taken

The snapshot generated during this test (`openbao-20261029-172211.snap`) was
uploaded to Garage S3 and retained as the latest backup.

## How it was verified

- Snapshot creation and upload verified via Dokploy execution logs and `rclone copy` from Garage S3.
- Snapshot restore verified on throwaway podman instance: web UI unseal successful with real keys, `bao kv list kv/` readable.

## Still open

- None for OpenBao backups: snapshot creation, upload to Garage, and restore are verified.

## Follow-up 2026-10-30

- The snapshot script now stages the snapshot in `/etc/dokploy/backups/openbao`
  (mode 700) instead of `/tmp/openbao-backup`. Reason (owner, 2026-10-30): the
  task's `/tmp` is not the `/tmp` that the host Docker daemon mounts into the
  `amazon/aws-cli` container, while `/etc/dokploy` is the same path on both
  sides. The mechanism was not checked on the host. The owner changed the
  Dokploy task to this version on the VPS before the repo copy was updated.
  Whether a copy of the previous script was kept is not recorded; the `/tmp`
  version is in commit `80a33c4`. The Dokploy task runs this version: checked
  2026-10-30 by reading the schedule through the Dokploy MCP (`schedule-one`)
  and comparing it with the repo copy (identical).
- The `/etc/dokploy` version was run and tested by the owner on 2026-10-30
  (owner's report; the run itself is not recorded here).
- Not verified: whether the 2026-10-29 20:30 UTC cron run (02:00 IST, object
  `openbao-20261029-203000.snap`) used the `/tmp` or the `/etc` version.
  The run log is not readable through the MCP.
- Not verified: pruning to 14 backups. Six objects existed on 2026-10-30
  (Dokploy MCP `backup-listBackupFiles` on the Garage destination), so the prune
  step has not run yet.
