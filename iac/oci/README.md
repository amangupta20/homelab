# IaC — Oracle Cloud

OpenTofu root for Oracle Cloud Infrastructure (OCI), separate from the Xen
Orchestra root in `iac/` so the two have separate state and a mistake in one
cannot plan changes to the other.

**Status:** configured, not applied, and nothing has talked to Oracle yet. `fmt`,
`validate`, `tflint` and the provider lock ran locally. `tofu init` ran against the
real bucket on 2026-11-04 with a throwaway passphrase, and the state store was
tested the same day on a scratch key: encrypted state went up and only ciphertext
was stored. `run.sh` has not completed a run, because the passphrase and Oracle
secrets below do not exist yet.

## What it manages

New resources only. The running VPS stays by-hand
(`decisions/vps-outside-opentofu.md`; the owner reconfirmed on 2026-11-04).

To make that a permission and not just a habit, OpenTofu's IAM (identity and
access management) user may only manage one compartment, `homelab-iac`.
Compartments are OCI's folders for resources, and a policy on one does not reach
resources outside it, so this key cannot change the VPS as long as the VPS is
not inside `homelab-iac`.

`main.tf` creates nothing yet. The first apply only proves the chain works.

Security list and firewall rules for anything public need a decision on what the
public repo may show before they are written here (`AGENTS.md`, "Security flaws").

## First-time setup

All **UNTESTED**. The console steps are from memory of the OCI console, so
labels may differ.

1. **Oracle console:** create compartment `homelab-iac`, a user, a group holding
   that user, and an API key for the user. Download the private key. Add a policy
   in the tenancy root:

   ```text
   Allow group <group> to manage all-resources in compartment homelab-iac
   ```

2. **OpenBao:** create the state passphrase, once, and store the Oracle values.
   They are separate secrets because `bao kv put` replaces a whole secret, so
   re-running the Oracle command must not be able to erase the passphrase.
   `@file` keeps the key out of shell history; delete the file afterwards.

   ```bash
   openssl rand -base64 32 | tr -d '\n' | bao kv put -mount=kv general/tofu-state passphrase=-
   bao kv put -mount=kv general/oci tenancy_ocid=__ID__ user_ocid=__ID__ \
     fingerprint=__FP__ private_key=@key.pem region=__REGION__ \
     compartment_ocid=__ID__
   ```

   Already in place: the B2 bucket and key at `kv/general/tofub2` (limited to that
   one bucket, B2 authorize call, 2026-11-04).

3. **Keep a break-glass copy offline** of the API key and the state passphrase.
   OpenBao runs on the VPS, so if that machine is lost these are needed before
   OpenBao is back. Losing the passphrase loses the state.

## Use

**UNTESTED** until the setup above is done.

```bash
./run.sh init
./run.sh plan    # read it all; the pull request gets the short form in iac/README.md
./run.sh apply
```

There is no lock. B2 answers OpenTofu's conditional write with `501
NotImplemented` (tested 2026-11-04), so the one-writer rule in `iac/README.md` is
the only protection.

`run.sh` needs a token that can read `kv/general/tofub2`, `kv/general/oci` and
`kv/general/tofu-state`. These sit under `general` because OpenTofu serves the
whole setup, not one host (owner, 2026-11-05).

## State

Encrypted by OpenTofu before upload, at key `oci/terraform.tfstate` in a private
B2 bucket (the owner's choice, 2026-11-04). B2 stays reachable when home or Oracle
is down. The bucket has no lifecycle rules (B2 API, 2026-11-04), so B2 keeps every
old version of the state.

A second copy in Garage is planned but not built, so this is a single copy for
now (`plans/oci-state-backup.md`).

`tofu state pull` prints **decrypted** state, so never use it to make a copy. A
second copy has to be the encrypted object from the bucket.
