# Authentik

**Status:** not deployed yet. Written 2026-11-10 as the single sign-on (SSO) provider of
`plans/vps-foundations.md`, step 4 (the owner chose Authentik on 2026-11-10). Nothing here has run on the VPS.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| Authentik's `docker-compose.yml` (`goauthentik.io/docker-compose.yml`) | `2026.8.5`, 2026-11-10 | image, `server` and `worker` commands, `shm_size`, `/data`, the `AUTHENTIK_POSTGRESQL__*` variables |
| Authentik's configuration docs (`website/docs/install-config/configuration/configuration.mdx`) | tag `version/2026.8.5`, 2026-11-10 | `AUTHENTIK_WEB__BASE_URL`, the pooler section ("Use a PostgreSQL connection pooler"), `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` defaults, error reporting off by default |
| Authentik's `lifecycle/ak` | tag `version/2026.8.5`, 2026-11-10 | `ak healthcheck` for the health check; the image itself has none (`docker buildx imagetools inspect`) |
| Dokploy's template (`blueprints/authentik/` in `Dokploy/templates`) | commit `084d1cb15f`, 2026-10-15 | the worker starting after the server, to avoid a race filling the fresh `/data` volume |
| `ghcr.io/goauthentik/server` | `2026.8.5`, 2026-11-10 | arm64 image (`docker buildx imagetools inspect`) |

Choices that differ from the sources:

- **No bundled Postgres.** The database is `authentik` on the shared cluster, through `pg-proxy:5432`
  (`apps/vps/pg-proxy/`) to PgBouncer in **session** mode (`ansible/pigsty/pigsty.yml.template`). Authentik keeps
  everything in Postgres, including its task queue, and holds `LISTEN` connections and session advisory locks.
  Its docs say transaction pooling silently breaks those unless a second, direct endpoint is set; session mode
  does not, so no `AUTHENTIK_POSTGRESQL__DIRECT__*` is set. `CONN_MAX_AGE` stays at its default `0`, the docs'
  advice for session pooling. Why shared and not bundled: the cluster's B2 backups have a tested restore, and the
  tailnet round trip from pigsty-1 to the Dokploy VPS is 1 ms over a direct path (`tailscale ping`, 2026-11-10).
  The cost: SSO is down whenever pigsty-1 is.
- **No Docker socket, and the worker does not run as root.** Upstream mounts `/var/run/docker.sock` into the worker,
  as root, so Authentik can create outpost containers itself. Access to the socket is root on the VPS, and this is
  the most exposed service on it. Without the socket, the embedded outpost inside `server` still serves forward-auth
  for every app; any other outpost (LDAP, RADIUS, a proxy elsewhere) is a small Compose service deployed by hand once,
  with a token made in the admin interface. Running the worker as the image's user (uid 1000) is untested on the
  `/data` volume's permissions; check on the first deploy.
- **No published ports, no port 9443.** Traefik reaches port 9000; TLS ends at Traefik.
- **Three routers instead of one domain** (next section).
- **No `custom-templates` or `certs` volumes.** Nothing uses them yet.
- **Never asleep.** The owner turned Sablier off for it (2026-11-10): forward-auth checks call the container
  directly, so they would not wake it.

## Public login, tailnet-only admin

| Hostname | Who reaches it | What it serves |
|---|---|---|
| `AUTHENTIK_DOMAIN` | anyone; Let's Encrypt over HTTP-01 | everything except the two paths below |
| `AUTHENTIK_DOMAIN`, paths `/if/admin` and `/if/flow/initial-setup` | nobody: 403 | — |
| `AUTHENTIK_ADMIN_HOST` | the tailnet only (`100.64.0.0/10`, as `apps/vps/pgadmin/`); DNS-only record to the VPS's tailnet address, zone wildcard certificate | everything |

- The **first-start setup** (`/if/flow/initial-setup/`), which sets the `akadmin` password, is refused publicly so
  nobody else can claim the instance between the deploy and the owner's first visit. Do it on the admin hostname.
  No bootstrap password is set in the environment for the same reason the docs warn against it: it would sit in
  plain text in the container's environment.
- **This blocks the admin pages, not admin rights.** The API (`/api/v3/`) has to stay public, because the login
  flows and the user interface use it, so a stolen superuser session could still change settings from anywhere.
  Planned on top, in the admin interface, **UNTESTED**: an expression policy on the authentication flow that refuses
  superusers whose client address is outside the tailnet, and a second factor (TOTP or WebAuthn) required for every
  admin account. The client address comes from Traefik's `X-Forwarded-For`, which Authentik trusts only from private
  ranges (its default `TRUSTED_PROXY_CIDRS`); if Cloudflare's proxy ever sits in front, that address changes.

## Deploying

1. Pigsty: put the role's password in OpenBao (`kv/general/pigsty`, field `pg_user_authentik`), run
   `ansible/pigsty/render.sh`, then on the node `bin/pgsql-user pg-meta authentik`,
   `bin/pgsql-db pg-meta authentik` and `bin/pgsql-user pg-meta dbuser_owner` (the database UIs' access,
   `apps/vps/pgadmin/README.md`). **UNTESTED** for this app; Blinko went the same way.
2. OpenBao: the fields of `.env.example` at `kv/dokploy/authentik`.
3. DNS: the public record for `AUTHENTIK_DOMAIN`, and a DNS-only record for `AUTHENTIK_ADMIN_HOST` to the VPS's
   tailnet address.
4. Dokploy: a Compose service from this repo's `main`, path `apps/vps/authentik/compose.yaml`, no domain set in
   Dokploy (the routers are labels here), environment from OpenBao.
5. On the admin hostname: the initial setup, then the policy and second factor above.

## Backups

The database is in the shared cluster's backups (`systems/backups.md`). The `authentik-data` volume holds uploaded
icons and branding only, which can be uploaded again; no backup for it yet. Restoring Authentik means restoring the
database **and** having `AUTHENTIK_SECRET_KEY` from OpenBao.

## Things to watch

- `pg-proxy` closes connections idle for 30 minutes. Authentik's `LISTEN` connections are idle most of the time.
  Whether it reconnects cleanly after that is not known; check the worker log after the first idle half hour.
- How many server connections it holds in PgBouncer's pool, which is shared with Blinko on the same node.
- `AUTHENTIK_WEB__BASE_URL` becomes required in 2026.11 (configuration docs); it is already set.
