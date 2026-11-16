# IaC — VMs as code

I create VMs with OpenTofu (same config language as Terraform — if you know
one, you know the other). The provider `vatesfr/xenorchestra` talks to Xen
Orchestra's API and creates VMs there, so a VM is a config file, not a
hand-clicked pet.

Oracle Cloud has its own root and state: `oci/README.md`. The rest of this page
is the Xen Orchestra root.

## Files

- `run.sh` — runs `tofu` with every credential read from OpenBao, so nothing
  is written to disk or left in the shell: the B2 state key
  (`kv/general/tofub2`), the state passphrase (`kv/general/tofu-state`), and Xen
  Orchestra's address and token (`kv/homelab/xo`). After every command it
  syncs the state to Garage if it changed (below). `iac/oci/run.sh` is the
  same for Oracle Cloud.
- `lib/state-copy.sh` — that copy, shared by both roots.
- `backend.tf` — where the state lives, and its encryption.
- `provider.tf` — declares the Xen Orchestra provider. Holds no credentials:
  `run.sh` sets `XOA_URL`, `XOA_TOKEN` and `XOA_INSECURE` (Xen Orchestra's
  certificate is self-signed, `CN=xo-ce`, read 2026-11-16).
- `variables.tf` — the state passphrase.
- `vm.tf.example` — commented example VM. Copy to `vm.tf` and fill in your
  pool, template, storage, and network names. `vm.tf` itself is git-ignored
  so local names never leak into git.
- `vault.tf.example` — reading the Xen Orchestra login through OpenTofu's
  vault provider instead. Not used: `run.sh` reads it with `bao`.

## Use

Ran on 2026-11-16 with no resources yet: `init` reached B2 and `plan` reached
Xen Orchestra and reported no changes.

```bash
./run.sh init
./run.sh plan    # read it all; the pull request gets the short form below
./run.sh apply
./run.sh backup  # copy the state to Garage now, e.g. after a failed copy
```

Needs `bao` (logged in, `BAO_ADDR` set), `tofu` and `rclone`.

First boot still uses cloud-init (bakes in hostname, SSH keys, IP). OpenTofu
owns the VM's shape; cloud-init owns its first-boot personality.

## VM template

Every home VM is cloned from one template, `debian-13-cloud-<build>`: Debian
13's official generic cloud image with cloud-init, on `Local storage` (the host's
own disk; owner, 2026-11-16). One OS for every home VM is the rule in
`plans/home-overhaul.md`, "One operating system". A clone onto `Nvme` copies the
3.2 GB disk, which takes seconds.

`templates/debian-13.sh <build>` makes it: it checks the image's SHA-512
against Debian's `SHA512SUMS`, has Xen Orchestra download the image itself (so
it never crosses the tailnet), and turns it into a template without booting it.
Debian publishes `SHA512SUMS` over HTTPS with no signature file next to it
(checked 2026-11-16), so HTTPS is what vouches for the checksums.

**In place:** `debian-13-cloud-20261111-2659`, made 2026-11-16 with the steps
that script strings together (`journal/2026-11-16-debian-13-template.md`). The
script as a whole is **UNTESTED**; it was written from those steps.

**Boot-test a new build before using it:** clone a throwaway VM from it with a
cloud-init user and a temporary SSH key, log in, and check `cloud-init status
--long` says `done` with no errors. Then delete the VM with its disks.


Encrypted by OpenTofu before upload, with the same passphrase as `iac/oci/`, in
the same private Backblaze B2 bucket, at key `xcp-ng/terraform.tfstate`; never
in git (owner, 2026-11-16). B2 is the primary because it stays reachable when
home is down, and because state about the home machines should not live only on
them. Until 2026-11-16 this backend pointed at a Garage bucket that was never
created, so no state was lost by the move.

**Second copy in Garage.** After every command, `run.sh` compares the newest
copy in Garage's `opentofu` bucket with the encrypted object in B2. When they
differ it copies the object as `xcp-ng/<UTC time>.tfstate`, checks the copy byte
for byte, and keeps the newest 14 (`lib/state-copy.sh`,
`plans/oci-state-backup.md`). Garage is only the second copy, so it never
changes the exit code (owner, 2026-11-16): when Garage is down the command
prints a warning, and the next run of any command, even a `plan`, catches up.
Never copy with `tofu state pull`: it prints the state decrypted.

**One writer.** B2 answers OpenTofu's conditional write with `501
NotImplemented` (tested 2026-11-04), so OpenTofu cannot take a lock. No command
can detect that someone else applied in between: a plan always reads whatever
is in the bucket now. So the rule is the whole protection — one checkout runs
`./run.sh apply`, the plan summarised in the pull request comes from that same
checkout, produced immediately before the apply.

**Plans in pull requests.** This repo is public and a full plan can show IDs and
addresses, so paste only the summary and resource actions, and keep the full plan
out of the repo, pull requests and CI logs. This keeps only those lines (ran
against a scratch config on 2026-11-05; attribute values did not appear):

```bash
./run.sh plan -no-color | grep -E '^ +# |^Plan:|^No changes'
```

Read the full plan before applying; this short form is for the record, not for
deciding. Still check what it prints: a resource's name can identify something too.

**Backup:** losing the bucket loses the mapping between code and real VMs.
Whether it is backed up is tracked in `systems/backups.md`.

The backend was first used against the real bucket on 2026-11-16 (`./run.sh
init`). One thing CI cannot check: `tofu init -backend=false` skips the backend block
entirely, so a typo in `backend.tf` surfaces at your first real `tofu init`, not
in a pull request.

## Never commit

`*.tfvars`, `*.tfstate*`, `.terraform/`, `vm.tf`, `vault.tf`, `.env`,
anything with a token. State is never committed — it holds secrets, so it lives
encrypted in B2, with encrypted copies in Garage.
