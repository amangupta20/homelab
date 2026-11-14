# Every service gets a local backup tier; the important ones also get an encrypted offsite tier

Decided: 2026-10-31. Status: in force — approved by the owner.

## The pattern

| | Tier 1: local | Tier 2: offsite |
|---|---|---|
| Who gets it | every service with state | services the owner names (list below) |
| Where | Garage at home (`systems/backups.md`) | Backblaze B2, encrypted before upload |
| How many versions | many (OpenBao keeps 14 today) | few: 3 daily, 1 weekly, 1 monthly |
| Protects against | everyday mistakes: a bad upgrade, a deleted file, "go back to last Tuesday" | losing the site: the house, TrueNAS, or a compromise that wipes Garage |
| Restore speed | fast, on the LAN | slower; downloads are free up to 3× what is stored (B2 pricing as noted by the owner, 2026-10-14) |

Tier 2 is sent **from the source**, not copied from Garage, so a missing or
broken backup in Garage never reaches B2. The procedure is
`skills/back-up-a-service/`.

**Tier 2 services (owner to confirm):** OpenBao first. Others get a lighter
version for learning, chosen one at a time (`plans/offsite-backups.md`).

**Shared Postgres gets tier 2, ahead of its tier 1** (owner, 2026-11-06). Garage at
home is not available yet, so B2 is its only repository until home is back. It keeps
few versions, in pgBackRest's own terms (`plans/shared-postgres.md`, "Backups").
Its encryption passphrase is kept in OpenBao only, an exception to rule 2 below (owner,
2026-11-06): OpenBao restores from B2 (tested 2026-10-31) with unseal keys kept offline.

## Why

- **One copy offsite fails when it is needed.** If ransomware encrypts the
  data or a migration corrupts it, the next nightly run would replace the only
  good offsite copy with the broken one. Problems are often noticed days later.
  A few versions cost little: restic, Kopia and Borg store only what changed
  between versions.
- **Sending from the source keeps the tiers independent.** Copying Garage's
  bucket to B2 is simpler but carries every Garage problem along.
- **Small enough to be cheap.** The important services' backups probably fit
  in B2's 10 GB free tier (guess, not measured).

## Rules that come with it

1. **Encrypt before upload.** restic, Kopia and Borg do it by default;
   pgBackRest needs `repo2-cipher-type`.
2. **The offsite encryption key must not depend on the lab.** If the key lives
   only in OpenBao and the lab is lost, OpenBao's own backup is locked behind a
   key nobody can reach. Each tier-2 key is kept in OpenBao *and* somewhere
   outside the lab the owner chooses (never in this repo).
3. **The lab should not be able to delete the offsite copies.** A backup host
   whose B2 key can delete files lets an attacker on that host wipe both tiers.
   Options: B2 Object Lock for a few days, or a key that cannot delete plus B2
   lifecycle rules for cleanup. Whether either works with the chosen tool's
   pruning is untested. Same principle as `decisions/agent-access.md`: backups sit
   on a boundary the lab's own credentials cannot write to.
4. **B2 hides deleted files by default** instead of removing them; the bucket
   needs a lifecycle rule that keeps only the current version, or cleanup frees
   no space.
5. **The restore rule still applies.** A tier counts only after a test restore
   from it (`systems/backups.md`, "The rule").

## Proposed change, 2026-11-14 (not in force until the owner approves)

From `plans/home-overhaul.md`, "Design". Tier 1 is no longer always Garage:

- **Data in a ZFS dataset on TrueNAS:** tier 1 is ZFS snapshots plus either the
  app's own backup tool writing to the other disk (Nextcloud's Borg to
  BorgWarehouse) or a ZFS copy on the other disk. One of the two, never both.
- **Garage stays tier 1** for the VPS, for apps' local Docker volumes and for
  pgBackRest.
- **Tier 2 from a Borg repository:** for an app whose only capture is its own
  Borg backup, the offsite copy is that repository copied to B2 after a
  `borg check`. That is copying from tier 1, which the pattern above rules out;
  the check limits the risk of carrying a damaged repository offsite.

## Cost / what this rules out

- Two backup paths per tier-2 service to schedule, watch and test.
- A B2 account, bucket and scoped key, stored in OpenBao.
- Rules 2 and 3 are manual steps the owner has to do outside the lab.
- Rules out "copy the whole Garage bucket offsite" as the offsite plan.

## Where it lives

`systems/backups.md` (what each service actually has),
`skills/back-up-a-service/` (how), `plans/offsite-backups.md` (OpenBao first),
`decisions/open-questions.md` ("Backups").
