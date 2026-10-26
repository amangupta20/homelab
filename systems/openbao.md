# OpenBao — where secrets live

OpenBao is the secret store: every password and token in one place on the
tailnet, read by machines at deploy time, never written into git.

**Status:** planned, not deployed. No command on this page has been run
against a real OpenBao server yet.

The problem: this repo gets checked out on 5 machines. Copying a `.env` file
with passwords to 5 places means 5 copies to leak, 5 copies to rotate, 5
copies to forget.

The fix: passwords live in one locked box (OpenBao), and the repo only holds
the *path* to each password (like `kv/homelab/xo-token` — an address, not the
key). Each machine logs into the box once; OpenTofu fetches the value when it
runs. Nothing secret ever touches git.

## OpenBao vs HashiCorp Vault

Same thing for your purposes: same API, same Terraform provider
(`hashicorp/vault`). The difference is the license — Vault is
HashiCorp-owned (BSL), OpenBao is the open fork (MPL). For a homelab, run
OpenBao and skip the license question. The `bao` command works like `vault`.

## Where the box runs

On the VPS, listening only on its Tailscale address
(`decisions/foundations-on-vps.md`). It must be always-on and reachable from
every checkout and from both sides of the lab; the VPS is the always-on side,
and both sides share the tailnet. No public URL (see below why).

Storage backend: Raft on the VPS's disk (`decisions/openbao-raft-storage.md`).
Back it up with Raft snapshots — losing that disk means losing every secret at
once.

## Don't put it on the internet

OpenBao holds every secret at once, so it's the highest-value target you own.
Tailscale already gives every checkout encrypted, identity-checked access with
no open ports. Opening it publicly buys zero uptime and adds login
brute-force, TLS bugs, and snapshot-theft risk.

If a machine without Tailscale ever needs one secret: give it that one secret
through a narrow relay (Dokploy secret reference, or a CI runner that is on
the tailnet). Never open the box itself.

## Locking it down (once it's running on the tailnet)

- Unseal keys stay offline. Don't store auto-unseal keys next to the data.
- TLS on port 8200 even on the tailnet (self-signed cert is fine, pin it), so
  other tailnet devices can't sniff or impersonate.
- Delete the initial root token after setup. Log in with a user account, and
  give each use its own narrow permission: checkouts read `kv/homelab/*` only,
  Dokploy reads only its own paths.
- Turn on the audit log (`bao audit enable ...`) and actually look at it —
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

## Daily use (each checkout, no .env file) — UNTESTED sketch

```bash
export VAULT_ADDR='https://10.22.33.X:8200'
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

## Two container managers

The lab has two, and they need different answers:

- **Remote VPS — Dokploy.** v0.30+ reads the box natively: Settings -> Secrets ->
  Add Provider, then `${{vault...}}` references in container env. Resolved at
  deploy time, never stored in Dokploy's database. Compose stops needing
  `.env` files.
- **Homeserver — Portainer today.** Portainer does not read OpenBao, so secrets
  have to reach the container another way: a sidecar logs in with its own
  AppRole and writes files into `/run/secrets`, and the stack reads files
  instead of environment values. Which manager replaces Portainer is still open
  (Arcane is the likely candidate, not confirmed); if it turns out to have a
  native vault provider, use that and drop the sidecar for that stack.

## Rules

- Never commit `.env`, `*.tfvars` with secrets, `*.tfstate`, `.vault-token`.
- If a secret was ever committed, rotate it in the box. Deleting it from git
  is not enough — git history keeps it.
