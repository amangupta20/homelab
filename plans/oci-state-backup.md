---
type: plan
status: "blocked"
verified: "no (design only; nothing built, Garage unreachable 2026-11-04)"
hosts:
  - TrueNAS VM
tags:
  - plan
  - backups
  - opentofu
  - oci
---

# Second copy of the Oracle Cloud state in Garage

**Status:** blocked on Garage, which is staying down for now (owner, 2026-11-05).
It timed out from the owner's workstation on 2026-11-04 (`curl` to its S3 port).

**Goal:** the encrypted state in Backblaze B2 (`iac/oci/README.md`) also exists in
Garage at home, so losing the B2 account or bucket does not lose the state.

**Done when:** a restore test from a Garage copy is recorded in `journal/`: a
temporary checkout using that copy runs `tofu plan` and reports no changes.

**Until then:** the state is a single copy in B2. B2 keeps old versions (the
bucket has no lifecycle rules, B2 API, 2026-11-04), which covers a corrupted state
but not losing the account.

Everything below is a design and **UNTESTED**.

## Design

- `iac/oci/run.sh` copies the object after anything that changes state: `apply`,
  `destroy`, `import`, `state ...`. Copying on each change needs no schedule and
  no credentials on the VPS, because state only changes through this wrapper.
- The copy is the encrypted object from the bucket. Never `tofu state pull`: it
  prints decrypted state (tested 2026-11-04).
- Copies are timestamped, `oci/<timestamp>.tfstate`, keeping the last 14, the
  count OpenBao uses. A single mirror would overwrite the good copy with a
  corrupted one. Garage has no S3 versioning, as recalled and unverified.
- A failed copy warns loudly but does not fail the command, because the change has
  already happened in Oracle. `./run.sh backup` retries it.

## Steps

1. Garage is back up. — gate: its S3 port answers from the checkout that applies.
2. Create a bucket and a key limited to it, and store the key in OpenBao. — gate:
   the key can write and list that bucket and nothing else.
3. Add `rclone`, pinned in `mise.toml`, and the copy step to `run.sh`. — gate: one
   `apply` leaves a new timestamped copy, and with Garage unreachable the same
   command warns and still exits as `tofu` did.
4. Restore test. — gate: the "Done when" check, recorded in `journal/`.
5. Update `iac/oci/README.md` and `systems/backups.md`.

## Links

`iac/oci/README.md`, `systems/backups.md`, `decisions/backup-tiers.md`.
