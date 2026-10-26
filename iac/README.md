# IaC — VMs as code

I create VMs with OpenTofu (same config language as Terraform — if you know
one, you know the other). The provider `vatesfr/xenorchestra` talks to Xen
Orchestra's API and creates VMs there, so a VM is a config file, not a
hand-clicked pet.

## Files

- `provider.tf` — declares the Xen Orchestra provider. Holds no credentials.
  Login comes from environment variables (`XOA_URL`, `XOA_TOKEN`) or from the
  vault (see `vault.tf.example`).
- `vm.tf.example` — commented example VM. Copy to `vm.tf` and fill in your
  pool, template, storage, and network names. `vm.tf` itself is git-ignored
  so local names never leak into git.
- `vault.tf.example` — same idea for vault-backed credentials. Copy to
  `vault.tf` when OpenBao is running.

## Use

```bash
cp vm.tf.example vm.tf   # then edit names inside
export XOA_URL=wss://xo-host
export XOA_TOKEN=xxxx     # or: bao login, see docs/secrets-openbao.md
tofu init
tofu plan                 # read this before applying
tofu apply
```

First boot still uses cloud-init (bakes in hostname, SSH keys, IP). OpenTofu
owns the VM's shape; cloud-init owns its first-boot personality.

## State

State lives in a Garage bucket on TrueNAS (`homelab-tofu-state`, key
`xcp-ng/terraform.tfstate`), never in git. `backend.tf` holds the bucket, key and
endpoint; credentials come from the environment, not the file.

Prerequisites before the first `tofu init` works:

- Bucket `homelab-tofu-state` exists in Garage and the S3 key used can read and
  write it.
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are exported for that key,
  ideally by the same wrapper that fetches the Xen Orchestra token from
  OpenBao.

**One writer.** Garage has no S3 conditional writes, so OpenTofu cannot take a
lock. Only one checkout runs `tofu apply`; everything else may plan. Before
applying, confirm the state you are about to change is the one in the bucket
(`tofu plan` after `tofu init -upgrade` will show drift if it is not).

**Backups.** A scheduled `tofu state pull` export goes offsite alongside the
other backups — losing the bucket loses the mapping between code and real VMs.

Note: this backend has not been exercised against a real bucket yet. Everything
that could be checked locally (fmt, validate, tflint, provider lock) has been.

## Never commit

`*.tfvars`, `*.tfstate*`, `.terraform/`, `vm.tf`, `vault.tf`, `.env`,
anything with a token. State files contain secrets — they stay local.
