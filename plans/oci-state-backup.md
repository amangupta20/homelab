---
type: plan
status: "done"
verified: "yes (built and restore-tested 2026-11-16)"
hosts:
  - TrueNAS VM
tags:
  - plan
  - backups
  - opentofu
  - oci
---

# Second copy of the Oracle Cloud state in Garage

**Status:** done 2026-11-16. Built for both OpenTofu roots, not only Oracle Cloud
(owner, 2026-11-16): `iac/lib/state-copy.sh`, called by `iac/run.sh` and
`iac/oci/run.sh`. The Oracle state's copy passed the restore test the same day
(`journal/2026-11-16-restore-test-tofu-state-garage.md`).

**Goal:** the encrypted state in Backblaze B2 (`iac/oci/README.md`) also exists in
Garage at home, so losing the B2 account or bucket does not lose the state.

**Done when:** a restore test from a Garage copy is recorded in `journal/`: a
temporary checkout using that copy runs `tofu plan` and reports no changes.

**Until then:** the state is a single copy in B2. B2 keeps old versions (the
bucket has no lifecycle rules, B2 API, 2026-11-04), which covers a corrupted state
but not losing the account.

The design below is what was built. Where the build differs, the step says so.

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
   Done: it answered from the workstation on 2026-11-16.
2. Create a bucket and a key limited to it, and store the key in OpenBao. — gate:
   the key can write and list that bucket and nothing else. Done 2026-11-16: the
   owner created bucket `opentofu` and its key, at `kv/general/tofugarage`. Writing,
   listing and deleting a test object worked; listing buckets showed only
   `opentofu`, and another bucket's name answered 404 (signed `curl`).
3. Add `rclone`, pinned in `mise.toml`, and the copy step to `run.sh`. — gate: one
   `apply` leaves a new timestamped copy, and with Garage unreachable the same
   command warns and still exits as `tofu` did. Built 2026-11-16; the first copy
   was made with `./run.sh backup`, not an `apply`. With Garage unreachable
   (tested 2026-11-16 by pointing it at a closed port), the command warns and
   keeps `tofu`'s exit code; `./run.sh backup` exits 1.
4. Restore test. — gate: the "Done when" check, recorded in `journal/`. Done
   2026-11-16.
5. Update `iac/oci/README.md` and `systems/backups.md`. Done 2026-11-16.

## Links

`iac/oci/README.md`, `systems/backups.md`, `decisions/backup-tiers.md`.
