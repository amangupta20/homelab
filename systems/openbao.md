# OpenBao — where secrets live

OpenBao is the secret store: every password and token in one place on the
tailnet, read by machines at deploy time, never written into git.

**Status:** running on the VPS since 2026-10-26 (`apps/vps/openbao/`); backup
and restore test not done yet. Commands not marked as run have not been run
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

Storage backend: Raft on the VPS's disk (owner's choice, 2026-10-26). It is
built into OpenBao, so there is no second database to run and back up, and it
has its own snapshot command. Back it up with Raft snapshots taken through
OpenBao, not by copying the volume while it runs — losing that disk means
losing every secret at once.

## Don't put it on the internet

OpenBao holds every secret at once, so it's the highest-value target you own.
Tailscale already gives every checkout encrypted, identity-checked access with
no open ports. Opening it publicly buys zero uptime and adds login
brute-force, TLS bugs, and snapshot-theft risk.

If a machine without Tailscale ever needs one secret: give it that one secret
through a narrow relay (Dokploy secret reference, or a CI runner that is on
the tailnet). Never open the box itself.

## How it is set up (2026-10-26)

- **Unsealing:** initialised with 3 unseal pieces; any 2 unseal it. The
  pieces are kept offline, apart from each other (where is not written down
  anywhere in this repo). After every restart someone enters 2 of them with
  `bao operator unseal`. A leaked or lost piece is replaced by
  `bao operator rekey`, which needs 2 current pieces.
- **Root token:** revoked after setup. `bao operator generate-root` makes a
  new one from 2 pieces when needed.
- **Logins:** `userpass`, one user per person, `admin` policy for the owner.
- **Audit log:** declared in the server config
  (`apps/vps/openbao/compose.yaml`). OpenBao 2.x refuses `bao audit enable`
  ("use declarative, config-based audit device management instead").
- **Address and certificate:** `apps/vps/openbao/README.md`, "TLS".

## Locking it down (once it's running on the tailnet)

- Unseal keys stay offline. Don't store auto-unseal keys next to the data.
- TLS on port 8200 even on the tailnet (self-signed cert is fine, pin it), so
  other tailnet devices can't sniff or impersonate.
- Delete the initial root token after setup. Log in with a user account, and
  give each use its own narrow permission: checkouts read `kv/homelab/*` only,
  Dokploy reads only `kv/dokploy/*` (below).
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

## Daily use (each checkout, no .env file)

Each machine needs only the address, `BAO_ADDR=https://<bao domain>:8200`
(`apps/vps/openbao/README.md`, "TLS"). The certificate is a public one, so no
certificate file. On a desktop session that uses systemd, a file in
`~/.config/environment.d/` sets it for every terminal without touching the
shell's startup files (done on the owner's workstation, 2026-10-26).

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

## Two container managers

The lab has two, and they need different answers:

- **Remote VPS — Dokploy.** v0.30+ reads the box natively: Settings -> Secrets ->
  Add Provider, then `${{vault...}}` references in container env. Resolved at
  deploy time, never stored in Dokploy's database. Compose stops needing
  `.env` files. The running Dokploy is v0.30.10, and its container reaches
  OpenBao's health endpoint (checked 2026-10-27).
  Every secret Dokploy deploys lives under `kv/dokploy/<app>`, and
  Dokploy's token reads that whole folder and nothing else (owner,
  2026-10-27). Dokploy can see every app's environment and controls every
  container on the VPS anyway, so a policy per app would protect little; the
  boundary that matters is between Dokploy's secrets and the rest of
  OpenBao. Dokploy's own token is kept outside that folder. Reference
  format (Dokploy docs, provider page): `${{vault.<provider>.dokploy/<app>:<key>}}`
  — the path leaves out the `kv/` mount and `data/`.
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
