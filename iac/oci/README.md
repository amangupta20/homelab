# IaC — Oracle Cloud

OpenTofu root for Oracle Cloud Infrastructure (OCI), separate from the Xen
Orchestra root in `iac/` so the two have separate state and a mistake in one
cannot plan changes to the other.

**Status:** running, with no resources yet. `./run.sh apply` ran on 2026-11-05 and
wrote the first encrypted state to B2; a second plan reported no changes
(`journal/2026-11-05-opentofu-on-oracle-cloud.md`).

## What it manages

New resources only. The running VPS stays by-hand
(`decisions/vps-outside-opentofu.md`; the owner reconfirmed on 2026-11-04).

This root runs in a separate, new Oracle Cloud account (tenancy), not the one holding
the running VPS (owner, 2026-11-05). Its key has no access to that other account, so
it cannot change the VPS.

Inside this account, OpenTofu's IAM (identity and access management) user may only
manage one compartment, `homelab-iac`. Compartments are OCI's folders for resources,
and a policy on one does not reach resources outside it. A scratch plan on 2026-11-05
returned no instances in `homelab-iac` or the root, and the API logged
`NotAuthorizedOrNotFound`. The provider turns that refusal into an empty list, so a
data source that returns nothing here may mean "not allowed", not "none exist".

`main.tf` creates nothing yet. The first apply only proves the chain works.

Security list and firewall rules for anything public need a decision on what the
public repo may show before they are written here (`AGENTS.md`, "Security flaws").

## Staying free

This is a pay-as-you-go account that should only use Always Free resources. The
owner's research (2026-11-05) is that the 2026 Ampere cut applies to free-tier
accounts, and pay-as-you-go keeps 4 OCPUs and 24 GB.

- **Alerts:** a budget with alert rules, set up by the owner in the console on
  2026-11-05. It only warns; it does not stop spending. No alert has fired yet, so
  delivery is untested.
- **Quotas:** none, by the owner's choice for now. Nothing in Oracle blocks a paid
  shape or extra disk, so reading each plan is the check: anything outside the free
  shapes and 200 GB of disk costs money.

## First-time setup

Done once on 2026-11-05 in the OCI console; labels may change.

1. **Compartment:** Identity & Security → Compartments → Create compartment.
   Name `homelab-iac`, parent the root compartment. Keep its OCID. It must exist
   before step 4, which refers to it by name.
2. **Group:** Identity & Security → Domains → Default → User management → Groups →
   Create group, named `tofu-homelab`.
3. **User and key:** on the same tab, Users → Create, in that group. Email goes in
   as `name+tofu@example.com`; the suffix comes before the `@`. Make the key locally,
   so the private half never passes through a browser, then paste the public half at
   the user's API keys → Add API key → Paste public key:

   ```bash
   mkdir -m 700 ~/oci-setup && openssl genrsa -out ~/oci-setup/key.pem 2048
   openssl rsa -pubout -in ~/oci-setup/key.pem -out ~/oci-setup/pub.pem
   ```

4. **Policy:** Identity & Security → Policies, with the root compartment selected,
   Create policy, manual editor:

   ```text
   Allow group 'Default'/'tofu-homelab' to manage all-resources in compartment homelab-iac
   ```

5. **OpenBao:** create the state passphrase, once, and store the Oracle values. They
   are separate secrets because `bao kv put` replaces a whole secret, so re-running
   the Oracle command must not be able to erase the passphrase. Then delete
   `~/oci-setup`. The bucket and its key are at `kv/general/tofub2` (limited to that
   one bucket, B2 authorize call, 2026-11-04).

   ```bash
   openssl rand -base64 32 | tr -d '\n' | bao kv put -mount=kv general/tofu-state passphrase=-
   bao kv put -mount=kv general/oci tenancy_ocid=__ID__ user_ocid=__ID__ fingerprint=__FP__ \
     private_key=@$HOME/oci-setup/key.pem region=__REGION__ compartment_ocid=__ID__
   ```

**Recovery:** there is no offline copy of these (owner's choice, 2026-11-05). If the
VPS is lost they come back by restoring an OpenBao snapshot (`systems/openbao.md`).
Losing the passphrase loses the state.

## Use

All three ran on 2026-11-05.

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
