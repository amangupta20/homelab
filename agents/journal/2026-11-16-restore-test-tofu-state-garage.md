# 2026-11-16 — OpenTofu state copied to Garage, and the copy restore-tested

**Who:** Claude Code, at the owner's request  **Scope:** OpenTofu state of `iac/oci/` and `iac/`; Garage bucket `opentofu`  **Mode:** write
**Task:** keep every OpenTofu root's state in B2 with a second copy in Garage (`plans/oci-state-backup.md`)  **Skill:** none

## What changed

- The owner created Garage bucket `opentofu` and a key limited to it (`kv/general/tofugarage`); the agent added the
  `endpoint_url` and `region` fields after testing them.
- `iac/lib/state-copy.sh` copies a root's encrypted state object from B2 to Garage, checks it, and keeps the newest 14.
  `iac/oci/run.sh` and the new `iac/run.sh` run it after every command and ignore its result, so Garage never fails
  OpenTofu; it copies only when Garage's newest copy differs from B2, so a missed copy is made on the next run.
- First copy: `iac/oci/run.sh backup` wrote `oci/20261116T131648Z.tfstate` to Garage.
- The Xen Orchestra root (`iac/`) moved its backend from a Garage bucket that was never created to the B2 bucket, key
  `xcp-ng/terraform.tfstate`, encrypted like `iac/oci/`. `./run.sh init` and `./run.sh plan` ran; it has no resources, so
  no state object was written and nothing was copied.

## Snapshot / backup taken

None needed: nothing in B2 or Oracle Cloud was written. The B2 bucket keeps every old version of the state.

## How it was verified

- The key: signed `curl` against Garage. Writing, listing and deleting a probe object worked; listing buckets showed only
  `opentofu`; another bucket's name answered 404; a request signed for region `us-east-1` was refused with "expected
  garage".
- The copy: `state-copy.sh` compares the SHA-256 of the B2 object and the Garage copy; they matched.
- **Garage unreachable:** with a stand-in `bao` that pointed Garage at a closed port, `./run.sh plan` warned and
  exited 0, a failing `tofu` call kept its own exit code (1), and `./run.sh backup` exited 1. A first version hung for
  minutes on rclone's default retries, so the calls now run with `--retries 1 --low-level-retries 2`.
- **Catching up:** with the existing Garage copies moved aside, a plain `./run.sh plan` copied the state
  (`oci/20261116T135656Z.tfstate`); the next `plan` copied nothing. The moved copies were put back.
- **Restore test:** in a scratch copy of `iac/oci/` with a `backend "local"` override, the newest Garage copy was
  downloaded as the state (still in OpenTofu's encrypted form), `tofu init` ran, and `./run.sh plan -lock=false`
  printed `No changes. Your infrastructure matches the configuration.` The scratch copy was deleted afterwards.

## Still open

- The same restore test for `iac/`, once it holds a resource.
