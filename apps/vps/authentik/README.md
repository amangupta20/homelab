# Authentik

**Status:** running on the VPS since 2026-11-10 (`agents/journal/2026-11-10-deploy-authentik.md`), the single sign-on (SSO)
provider of `agents/plans/vps-foundations.md`, step 4 (the owner chose Authentik on 2026-11-10). No app signs in through it
yet, and its database restore is not tested.

## Deploying

1. Pigsty: put the role's password in OpenBao (`kv/general/pigsty`, field `pg_user_authentik`), run
   `ansible/pigsty/render.sh`, then on the node `bin/pgsql-user pg-meta authentik`,
   `bin/pgsql-db pg-meta authentik` and `bin/pgsql-user pg-meta dbuser_owner` (the database UIs' access,
   `apps/vps/pgadmin/README.md`). Ran on 2026-11-10; each reported OK (journal).
2. OpenBao: the fields of `.env.example` at `kv/dokploy/authentik`.
3. DNS: the public record for `AUTHENTIK_DOMAIN`, and a DNS-only record for `AUTHENTIK_ADMIN_HOST` to the VPS's
   tailnet address.
4. Dokploy: a Compose service from this repo's `main`, path `apps/vps/authentik/compose.yaml`, no domain set in
   Dokploy (the routers are labels here), environment from OpenBao, and the project added to the OpenBao
   provider's assignments (`systems/openbao.md`). Dokploy named it `compose-reboot-optical-matrix-gsjyeo`; renaming
   it through the API did not take, so its containers and volume carry that name.
5. On the admin hostname: the initial setup, then the policy and second factor (`NOTES.md`, "Set in
   Authentik, not in this repo").

## Backups

The database is in the shared cluster's backups (`systems/backups.md`). The `authentik-data` volume holds uploaded
icons and branding only, which can be uploaded again; no backup for it yet. Restoring Authentik means restoring the
database **and** having `AUTHENTIK_SECRET_KEY` from OpenBao.

## Things to watch

- `pg-proxy` closes connections idle for 30 minutes. Authentik's `LISTEN` connections are idle most of the time.
  Whether it reconnects cleanly after that is not known; check the worker log after the first idle half hour.
- How many server connections it holds in PgBouncer's pool, which is shared with Blinko on the same node.
- `AUTHENTIK_WEB__BASE_URL` becomes required in 2026.11 (configuration docs); it is already set.

Everything else, word for word, is in `NOTES.md`: "Derived from", "Public login,
tailnet-only admin", "Set in Authentik, not in this repo", "Email".
