# pgAdmin

**Status:** written 2026-11-09; not deployed yet. A web UI for the shared Postgres, reachable from the tailnet only
(`plans/shared-postgres.md`, "Database UIs"). The owner keeps whichever of pgAdmin and CloudBeaver gets used more.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| pgAdmin's container docs (`docs/en_US/container_deployment.rst`) | `REL-9_19`, 2026-11-09 | the `PGADMIN_*` variables, `/var/lib/pgadmin`, `/pgadmin4/servers.json`, port 80 |
| `dpage/pgadmin4` on Docker Hub | `9.19.0`, 2026-11-09 | arm64 image |

Dokploy's template was not read. Choices:

- **Tailnet only.** Traefik's `ipallowlist` lets in `100.64.0.0/10` only. Tried with a throwaway router on 2026-11-09:
  200 over the tailnet, 403 over the public IP, and 403 over the public IP with `X-Forwarded-For` and `X-Real-Ip`
  set to a tailnet address (the check uses the connection's own address). The hostname's DNS record points at the
  VPS's tailnet address, so it is not reachable from outside anyway; the allowlist covers someone sending the right
  `Host` to the public address.
- **The zone's wildcard certificate** from Traefik's `cloudflare` resolver (`systems/vps.md`, "Certificates"), so
  the hostname needs no public HTTP challenge and does not appear in certificate transparency logs by name.
- **Connects as `dbuser_owner` to `pg-proxy:5436`,** Pigsty's direct Postgres service, not PgBouncer
  (`apps/vps/pg-proxy/README.md`). `dbuser_owner` is in `dbrole_admin` and in each app's role, not a superuser
  (`ansible/pigsty/pigsty.yml.template`). Its password is in OpenBao (`kv/general/pigsty`, field
  `pg_user_dbuser_owner`) and is typed at connect time: `ALLOW_SAVE_PASSWORD` is off.
- **Asleep when idle,** behind Sablier (`apps/vps/sablier/README.md`, "Making an app sleep"): stopped after 30 minutes
  without requests, started by the next one, which waits up to 2 minutes. The tailnet allowlist runs before Sablier's
  middleware, so a request from outside the tailnet gets 403 and wakes nothing.
- **No backup.** The volume holds pgAdmin's own login and preferences, nothing that cannot be recreated from this
  folder and OpenBao.

## Adding an app's database

Add the app's role to `dbuser_owner`'s `roles` in the Pigsty template and run `bin/pgsql-user pg-meta dbuser_owner`
on the node (after `render.sh`). Each app database has `revokeconn`, so without the membership the connection is
refused with "User does not have CONNECT privilege".
