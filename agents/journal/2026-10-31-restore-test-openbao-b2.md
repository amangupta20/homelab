# 2026-10-31 — tested restore of OpenBao from Backblaze B2 offsite backup

**Who:** the owner, with Antigravity  **Scope:** remote VPS, Dokploy schedule `openbao-raft-snapshot`, Backblaze B2 offsite tier, workstation restore test  **Mode:** write
**Task:** complete offsite backup and restore test gate for `plans/offsite-backups.md`  **Skill:** `skills/back-up-a-service/`

## What changed

- Note on repo-leads-lab: the scheduled task script was updated and tested live ahead of merging to verify failure decoupling against the live offline homelab and execute the restore test before recording it here.
- Configured Backblaze B2 offsite backup destination (S3-compatible, EU region) with bucket lifecycle set to "Keep only the last version of the file".
- Updated Dokploy scheduled task `openbao-raft-snapshot` (cron `0 2 * * *`, timezone `Asia/Kolkata`, type `dokploy-server`):
  1. Renews the OpenBao snapshot token and Dokploy provider token.
  2. Takes a point-in-time Raft snapshot via OpenBao API.
  3. Uploads to Garage S3 with a 10-second connection timeout, logging a warning if Garage is unreachable rather than failing the run.
  4. Uploads to Backblaze B2 S3 (`<b2-bucket>/openbao/<snap-name>`) using `amazon/aws-cli` container, and prunes to retain the last 14 copies.
- Verified live execution of the schedule: created `openbao-20261031-182326.snap` (48,153 bytes) and uploaded to Backblaze B2 (with Garage unreachable while homelab was offline, proving failure decoupling).
- Verified restore on the workstation:
  - Downloaded `openbao-20261031-182326.snap` directly from Backblaze B2 using `rclone`.
  - Started a clean throwaway OpenBao 2.7.1 container (`podman run --name baorestore ...`).
  - Initialized with throwaway credentials, unsealed, and executed `bao operator raft snapshot restore -force /tmp/baorestore/openbao.snap`.
  - The instance adopted the cluster state, sealed with threshold 2 of 3 (the live cluster state).
  - Accessed Web UI on port 18200, where the owner entered 2 real unseal keys, logged in, and verified that secrets and configuration matched the live cluster.
  - Tore down and deleted the test container (`podman rm -f baorestore`), volume, and temporary files.

## Snapshot / backup taken

- Pre-change capture: the prior Dokploy task settings and script were captured in git (`apps/vps/openbao/host/dokploy-schedule-snapshot.sh` at commit `5ed2d2b` and `apps/vps/openbao/README.md`) prior to deploying changes to the live Dokploy task.
- Post-change backup: the snapshot generated during this test (`openbao-20261031-182326.snap`) was
  uploaded to Backblaze B2 and retained as the latest offsite backup.

## How it was verified

- Snapshot upload to Backblaze B2 verified via Dokploy execution logs and remote `rclone ls`.
- Snapshot restore verified on throwaway Podman instance: web UI unseal successful with real Shamir keys, secrets and paths verified by the owner.
- Teardown verified: test container, volume, and `/tmp/baorestore` removed cleanly.

## Still open

- None for OpenBao offsite backups: snapshot creation, upload to B2, decoupling from Garage, and test restore from B2 are verified.
