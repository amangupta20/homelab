# Secrets — where passwords live (OpenBao)

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

It must be always-on and reachable from all 5 checkouts — so not the burst
Hermes VM that gets powered off. Good candidates: the TrueNAS VM host, or any
small always-on VM. Tailscale-only. No public URL (see below why).

Storage: a Docker volume or directory holding `/vault/file`. Back it up like
any database — losing that disk means losing every secret at once.

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

## One-time setup (on the server)

```bash
docker run -d --name openbao --restart unless-stopped \
  -p 8200:8200 -v openbao-data:/vault/file \
  openbao/openbao:latest

export VAULT_ADDR='http://10.22.33.X:8200'   # your OpenBao IP
bao operator init -key-shares=1 -key-threshold=1  # save the keys OFFLINE
bao operator unseal
bao login        # paste the root token from init (one time)
bao secrets enable -path=kv kv-v2
bao kv put kv/homelab/xo url="wss://xo-host" token="__PASTE_ONCE__"
```

After this, the secret lives only in the box. Clear your shell history so the
pasted token doesn't linger there.

## Daily use (each checkout, no .env file)

```bash
export VAULT_ADDR='http://10.22.33.X:8200'
bao login -method=userpass username=aman   # once per machine; the token is
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

## Dokploy too

Dokploy (the container deploy UI) v0.30+ can read from the same box: Settings
-> Secrets -> Add Provider, then use `${{vault...}}` references in container
env. Resolved at deploy time, never stored in Dokploy's database. Same box,
same paths — Compose stops needing `.env` files too.

## Rules

- Never commit `.env`, `*.tfvars` with secrets, `*.tfstate`, `.vault-token`.
- If a secret was ever committed, rotate it in the box. Deleting it from git
  is not enough — git history keeps it.
