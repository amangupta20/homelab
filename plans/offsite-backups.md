---
type: plan
status: "in progress (OpenBao tier 2 complete; next is learning service)"
verified: "partially (OpenBao restore tested from B2 2026-10-31; learning service pending)"
hosts:
  - Remote VPS
  - TrueNAS VM
tags:
  - plan
  - backups
  - openbao
---

# Offsite backups (tier 2), OpenBao first

**Status:** in progress. Steps 0-3 complete 2026-10-31; OpenBao offsite backup and restore tested.
**Goal:** OpenBao's Raft snapshots also reach Backblaze B2, encrypted, sent
from the VPS rather than copied from Garage; then one smaller service follows
a lighter version of the same pattern, for practice.
**Done when:** a restore of OpenBao from the B2 copy into a throwaway
instance is recorded in `journal/`, and `systems/backups.md` lists both tiers
for OpenBao.

Today OpenBao's only backup is tier 1: a daily Raft snapshot from the VPS to
Garage at home, restore tested 2026-10-29 (`systems/backups.md`). The procedure
for each service is `skills/back-up-a-service/`; commands below are
**UNTESTED**.

## Steps

0. **Owner approves the pattern** in `decisions/backup-tiers.md` and confirms
   the tier-2 list. — gate: its Status line says in force (approved 2026-10-31).
1. **B2 set up by the owner.** Bucket created with lifecycle rule keeping only
   the last version; Application Key limited to that bucket (read/write).
   Endpoint, bucket, and keys set in `/etc/dokploy/snapshot.env` on the VPS.
   — gate: owner confirms B2 bucket and credentials tested in Dokploy.
2. **Add tier 2 to the snapshot task.** Update the snapshot task
   (`apps/vps/openbao/host/dokploy-schedule-snapshot.sh`) to upload the Raft
   snapshot directly to Backblaze B2 via S3 API, and prune old copies (keeping
   14). Decouple Garage and B2 with short timeouts on Garage so that an offline
   homelab does not prevent B2 offsite backup from running. — gate: script
   updated in Dokploy and repo; manual execution reaches B2.
3. **Restore test from B2.** Restore the latest snapshot from B2 into a scratch
   directory on the workstation and load it into a throwaway OpenBao, the way
   `journal/2026-10-29-restore-test-openbao.md` did from Garage. — gate:
   journal entry (`journal/2026-10-31-restore-test-openbao-b2.md`); `systems/backups.md` updated. (Done 2026-10-31).
4. **One learning service, lighter pattern.** The owner picks a small service
   (a candidate with little data, suggested in an earlier session: ntfy). Same
   steps with fewer versions, to practise the procedure and correct
   `skills/back-up-a-service/`. — gate:
   restore journal entry; skill Status updated.

## Links

`decisions/backup-tiers.md`, `skills/back-up-a-service/`,
`systems/backups.md`, `systems/openbao.md`, `apps/vps/openbao/README.md`,
`decisions/open-questions.md` ("Backups").
