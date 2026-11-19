# OpenBao — notes

Reasons, the pre-setup checklist and sketches behind `lab/systems/openbao.md`.

## OpenBao vs HashiCorp Vault

Same thing for your purposes: same API, same Terraform provider
(`hashicorp/vault`). The difference is the license — Vault is
HashiCorp-owned (BSL), OpenBao is the open fork (MPL). For a homelab, run
OpenBao and skip the license question. The `bao` command works like `vault`.

## Locking it down (once it's running on the tailnet)

- Unseal keys stay offline. Don't store auto-unseal keys next to the data.
- TLS on port 8200 even on the tailnet (self-signed cert is fine, pin it), so
  other tailnet devices can't sniff or impersonate.
- Delete the initial root token after setup. Log in with a user account, and
  give each use its own narrow permission: checkouts read `kv/homelab/*` only,
  Dokploy reads only `kv/dokploy/*` (`lab/systems/openbao.md`, "Two container managers").
- Turn on the audit log — declared in the server config, since OpenBao 2.x
  refuses `bao audit enable` (`apps/vps/openbao/compose.yaml`) — and actually look at it —
  even just error lines forwarded to ntfy.
- Back it up and test one restore.
- Patch it like you'd patch Xen Orchestra — secret-store bugs are CVEs too.

## One-time setup (on the server) — not written yet

A previous draft here ran the `latest` image on the file backend over plain
HTTP; all three contradicted the rules above, so it was removed rather than
kept as a plausible-looking recipe. The order:

1. Run a pinned OpenBao version (never `latest`) with the chosen storage and
   TLS on 8200.
2. `bao operator init`, keys saved offline; unseal.
3. Enable a kv-v2 engine at `kv/`, write `kv/homelab/xo` with the Xen
   Orchestra URL and token. Clear shell history afterwards.
4. Create the user and per-consumer policies, then delete the root token.
5. Take a backup and restore it once before trusting it.

## OpenTofu reading the box

The OpenTofu part below is an **UNTESTED** sketch.

```bash
bao login -method=userpass username=<you>  # once per machine; the token is
                                           # stored in ~/.vault-token (git-ignored)
tofu plan    # OpenTofu reads the secret from the box at runtime
tofu apply
```

The repo side holds only the address. Example (`iac/vault.tf.example`, copy
to `vault.tf` — it contains no secrets):

```hcl
data "vault_kv_secret_v2" "xo" {
  mount = "kv"
  name  = "homelab/xo"
}
# then: token = data.vault_kv_secret_v2.xo.data["token"]
```
