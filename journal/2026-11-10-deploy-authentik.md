# 2026-11-10 — deployed Authentik as the lab's single sign-on

**Who:** the owner, with Claude Code  **Scope:** new Dokploy project `authentik`, database `authentik` on `pigsty-1`  **Mode:** write
**Task:** step 4 of `plans/vps-foundations.md`  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- **Pigsty:** role and database `authentik` (PgBouncer session mode), and the role added to `dbuser_owner`
  (`ansible/pigsty/pigsty.yml.template`). Before writing, `render.sh --check` against the previous template said
  the node matched it; after `render.sh`, `bin/pgsql-user pg-meta authentik`, `bin/pgsql-db pg-meta authentik` and
  `bin/pgsql-user pg-meta dbuser_owner` each reported OK.
- **OpenBao:** `kv/general/pigsty` gained `pg_user_authentik`; `kv/dokploy/authentik` holds the stack's fields
  (`apps/vps/authentik/.env.example`), all generated.
- **Cloudflare:** a DNS-only `A` record for the admin hostname to the VPS's tailnet address. The public login
  domain needed none: an existing DNS-only wildcard already points at the VPS.
- **Dokploy:** new project and Compose service from this repo's `main` (`autoDeploy` off), created through the API;
  the project added to the OpenBao provider's assignments (22 after the change, token left masked).
- **Resend:** a key named `authentik`, sending access to the existing mail domain only.
- The owner ran the first-start setup on the admin hostname.

## Snapshot / backup taken

None: a new app that touches nothing existing (owner's choice, 2026-11-10). The provider's assignment list only
gained an entry.

## What went wrong

- The public deny rule covered the setup page but not the setup flow's API. Found by `curl` within minutes of the
  first start; the stack was stopped until the owner had run the setup, and the database showed no login, session
  or event before that. Fixed: Authentik now refuses the flow, and the public router refuses its API too.
- Renaming the Dokploy service (`appName`) through `compose.update` returned the old name; its containers carry
  Dokploy's random name.
- The first certificate request took a little under a minute; until then Traefik served its default certificate.

## How it was verified

- Deployed commit equal to `main` at the time (`b34bd8c`, Dokploy's deployment list). Both containers healthy after
  about two minutes (the first start runs the migrations).
- `curl`: `/-/health/live/` 200 on the public domain with a Let's Encrypt certificate; `/if/admin/` and the setup
  page 403 publicly; the admin hostname serves the zone's wildcard certificate and answers 403 when reached through
  the public address.
- Through PgBouncer's port 5433, a login as `authentik` reached Postgres 18.6; after setup, `akadmin` has a usable
  password and one authenticated session.
- Resend's SMTP server accepted the new key (login answered `235`); no mail sent yet.

## Still open

- No restore test of the `authentik` database from the cluster's backup.
- A second factor on `akadmin`, the tailnet-only policy for superuser logins, the recovery flow and a test reset
  (`apps/vps/authentik/README.md`).
- No app signs in through it yet, the gate of `plans/vps-foundations.md` step 4.
- Whether its idle `LISTEN` connections survive pg-proxy's 30-minute idle timeout.

## Follow-up, 2026-11-10

- Mail through Resend and the extra setup-path block deployed (commit `7fc18c0`); both containers healthy, and
  `curl` gets 403 on all four refused public paths.
- Recovery flow, the tailnet-only rule for superusers, and the owner's TOTP device set in Authentik
  (`apps/vps/authentik/README.md`, "Set in Authentik, not in this repo"). The owner's test reset went through.
- Still open from the list above: the database restore test, and an app signing in through it.
