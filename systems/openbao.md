---
type: system
tags:
  - system
  - openbao
  - secrets
  - security
---

# OpenBao — where secrets live

OpenBao is the secret store: every password and token in one place on the
tailnet, read by machines at deploy time, never written into git.

**Status:** running on the VPS since 2026-10-26 (`apps/vps/openbao/`); backup
details owned by `systems/backups.md`; restore tested 2026-10-29 from Garage
(`agents/journal/2026-10-29-restore-test-openbao.md`) and 2026-10-31 from Backblaze B2
(`agents/journal/2026-10-31-restore-test-openbao-b2.md`).
Commands not marked as run have not been run against a real OpenBao server
yet.

The problem: this repo gets checked out on 5 machines. Copying a `.env` file
with passwords to 5 places means 5 copies to leak, 5 copies to rotate, 5
copies to forget.

The fix: passwords live in one locked box (OpenBao), and the repo only holds
the *path* to each password (like `kv/homelab/xo-token` — an address, not the
key). Each machine logs into the box once; OpenTofu fetches the value when it
runs. Nothing secret ever touches git.

## Where the box runs

On the VPS, listening only on its Tailscale address
(`agents/decisions/foundations-on-vps.md`). It must be always-on and reachable from
every checkout and from both sides of the lab; the VPS is the always-on side,
and both sides share the tailnet. No public URL (see below why).

Storage backend: Raft on the VPS's disk (owner's choice, 2026-10-26). It is
built into OpenBao, so there is no second database to run and back up, and it
has its own snapshot command. Back it up with Raft snapshots taken through
OpenBao, not by copying the volume while it runs — losing that disk means
losing every secret at once.

## Don't put it on the internet

> [!WARNING] Keep OpenBao off the public internet
> OpenBao holds every secret at once, so it's the highest-value target you own.
> Tailscale already gives every checkout encrypted, identity-checked access with
> no open ports. Opening it publicly buys zero uptime and adds login
> brute-force, TLS bugs, and snapshot-theft risk.

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
- **Address and certificate:** `apps/vps/openbao/NOTES.md`, "TLS".

## Daily use (each checkout, no .env file)

Each machine needs only the address, `BAO_ADDR=https://<bao domain>:8200`
(`apps/vps/openbao/NOTES.md`, "TLS"). The certificate is a public one, so no
certificate file. On a desktop session that uses systemd, a file in
`~/.config/environment.d/` sets it for every terminal without touching the
shell's startup files (done on the owner's workstation, 2026-10-26).

How OpenTofu would read secrets from it is an **UNTESTED** sketch, in
`systems/notes/openbao.md`, "OpenTofu reading the box".

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
  Verified 2026-10-27 by `apps/vps/hermes-webui/`: its password is read from
  `kv/dokploy/hermes-webui` at deploy time, so the running app starts with a
  secret that is in neither the service environment nor the repo. Dokploy's own
  database was not checked. Two things fail before that works, and both were
  hit on the way:
  - the provider's **KV Mount** defaults to `secret`. Set it to `kv`; left at
    the default the deploy stops with a 403 on `secret/data/...`.
  - the token behind the provider needs `read` on `kv/data/dokploy/*` and
    `list` on `kv/metadata/dokploy/*` — one policy for the whole folder, not
    one per app.
  - the provider is assigned per Dokploy project. A new project has to be added to
    its assignments (Settings → Secrets Providers), or the deploy stops with
    `Vault provider "openbao" is not enabled for this project/environment`
    (pg-proxy, 2026-11-09). Through the API, `vaultProvider.update` needs the whole
    config back: send the token as Dokploy's mask `********`, which keeps the stored
    one (`mergeVaultProviderConfig`, Dokploy v0.31.0). The Dokploy MCP shows the token
    as `[REDACTED]`; sending that back would store it as the token.
  The provider token was created on 2026-10-27 as an orphan token with the
  `dokploy-read` policy and a 1024h period (creation time and period read back
  with `bao token lookup -accessor` on 2026-10-30; an earlier note here said
  768h), so it dies unless renewed within about 42 days.
  Renewing it is automated daily by the `openbao-raft-snapshot` scheduled task
  (`systems/backups.md`).
- **Homeserver — Portainer today.** Portainer does not read OpenBao, so secrets
  have to reach the container another way: a sidecar logs in with its own
  AppRole and writes files into `/run/secrets`, and the stack reads files
  instead of environment values. Which manager replaces Portainer is still open
  (Arcane is the likely candidate, not confirmed); if it turns out to have a
  native vault provider, use that and drop the sidecar for that stack.

## Backup and token renewal

- **Daily Raft snapshot and token renewal**: Automated via Dokploy scheduled
  task running `dokploy-schedule-snapshot.sh` (`apps/vps/openbao/NOTES.md`, "Host scripts"),
  which streams a Raft snapshot via OpenBao's HTTP API and renews Dokploy's
  provider token. Schedule, upload destinations, retention, and restore tests
  are owned by `systems/backups.md` (restore tested 2026-10-29 from Garage and
  2026-10-31 from Backblaze B2).

## Still to do

The OpenTofu half of step 3 in `agents/plans/vps-foundations.md` (checkouts reading
OpenBao at runtime).

## Rules

> [!IMPORTANT]
> - Never commit `.env`, `*.tfvars` with secrets, `*.tfstate`, `.vault-token`.
> - If a secret was ever committed, rotate it in the box. Deleting it from git
>   is not enough — git history keeps it.
> - Patch it like Xen Orchestra and read its audit log (`systems/notes/openbao.md`, "Locking it down").
