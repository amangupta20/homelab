---
type: plan
status: "not started (waits on the owner approving decisions/backup-tiers.md)"
verified: "no (nothing built)"
hosts:
  - Remote VPS
  - TrueNAS VM
tags:
  - plan
  - backups
  - openbao
---

# Offsite backups (tier 2), OpenBao first

**Status:** not started — waits on the owner approving
`decisions/backup-tiers.md`.
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
   the tier-2 list. — gate: its Status line says in force.
1. **B2 set up by the owner.** One bucket; a lifecycle rule keeping only the
   current version; deletion protection chosen (Object Lock, or a key that
   cannot delete — rule 3); an application key limited to that bucket. The key
   and a new restic password go into OpenBao, and the password is also kept
   outside the lab. — gate: owner confirms the outside copy exists (where it is
   stays out of this repo).
2. **Finish the pending snapshot-script change first.** On 2026-10-31 the
   owner's checkout had an uncommitted edit to
   `apps/vps/openbao/host/dokploy-schedule-snapshot.sh`: the cleanup trap
   removes only the snapshot file instead of the whole folder (`git diff`).
   Whether the live task runs it is unverified (an earlier session's notes say
   not yet). It is committed and made live before tier 2 is added, so two
   changes to the task are never mixed. — gate: one scheduled run succeeds
   with it.
3. **Add tier 2 to the snapshot task.** Install restic on the VPS host; after
   the Garage upload, send the same snapshot file to B2 with restic before the
   cleanup trap removes it, then `restic forget --keep-daily 3 --keep-weekly 1
   --keep-monthly 1 --prune`. Take a Dokploy backup of the task's settings
   first. — gate: `restic snapshots --tag openbao` lists one snapshot after a
   scheduled run, and the Garage upload still works.
4. **Restore test from B2.** Restore the latest snapshot into a scratch
   directory on the workstation and load it into a throwaway OpenBao, the way
   `journal/2026-10-29-restore-test-openbao.md` did from Garage. — gate:
   journal entry; `systems/backups.md` updated.
5. **One learning service, lighter pattern.** The owner picks a small service
   (a candidate with little data, suggested in an earlier session: ntfy). Same
   steps with fewer versions, to practise the procedure and correct
   `skills/back-up-a-service/`. — gate:
   restore journal entry; skill Status updated.

## Links

`decisions/backup-tiers.md`, `skills/back-up-a-service/`,
`systems/backups.md`, `systems/openbao.md`, `apps/vps/openbao/README.md`,
`decisions/open-questions.md` ("Backups").
