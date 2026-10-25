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

## Never commit

`*.tfvars`, `*.tfstate*`, `.terraform/`, `vm.tf`, `vault.tf`, `.env`,
anything with a token. State files contain secrets — they stay local.
