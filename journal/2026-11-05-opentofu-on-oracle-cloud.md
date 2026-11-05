# 2026-11-05 — set up OpenTofu for Oracle Cloud

**Who:** the owner, with Claude Code  **Scope:** Oracle Cloud identity settings, a B2 bucket, OpenBao  **Mode:** write
**Task:** first OpenTofu root for Oracle Cloud, new resources only (`iac/oci/README.md`)  **Skill:** none

## What changed

- Oracle Cloud, by the owner in the console: compartment `homelab-iac`, group and
  user `tofu-homelab`, an API key, and a policy limiting that group to the
  compartment.
- OpenBao, by the owner: new secrets `kv/general/oci` and `kv/general/tofu-state`.
  The B2 bucket and key at `kv/general/tofub2` already existed.
- B2: the first encrypted state file, `oci/terraform.tfstate`, from `./run.sh apply`.
  It holds one output. The apply added, changed and destroyed no resources.

## Snapshot / backup taken

None: nothing that holds data changed, and the running VPS was not touched. The
state itself has no copy outside B2 yet (`plans/oci-state-backup.md`).

## How it was verified

- `./run.sh plan` read the availability domains using the new key.
- The apply reported `Resources: 0 added, 0 changed, 0 destroyed`, and a second plan
  exited 0 with "No changes".
- The B2 API lists one object, and its only state fields are `encrypted_data`,
  `encryption_version`, `lineage`, `meta` and `serial`.
- A scratch plan listing instances returned none in `homelab-iac` and none in the
  tenancy root, and the API logged `NotAuthorizedOrNotFound`. The log was deleted
  before the refusals were matched to their calls, so this does not show which
  listing was refused.
- B2 returned `501 NotImplemented` for OpenTofu's lockfile on 2026-11-04, so there
  is no lock.

## Still open

- The VPS's compartment has not been read in the console, so "this key cannot reach
  the VPS" is expected but not confirmed (`decisions/open-questions.md`).
- The new secrets enter OpenBao's backups at the next daily snapshot (cron
  `0 2 * * *`). No offline copy exists, by the owner's choice. No restore has tested
  these secrets.

## Follow-up

Later on 2026-11-05: the owner says this Oracle account is brand new, with nothing in
its root compartment, so the VPS is in a different account. That answers the first
"Still open" item: this key cannot reach the VPS because it belongs to another
account, whichever compartment the VPS is in.
