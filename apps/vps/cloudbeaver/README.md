# CloudBeaver

**Status:** running (`agents/journal/2026-11-09-deploy-db-admin-uis.md`). A web UI for the shared Postgres, reachable from the tailnet only
(`agents/plans/shared-postgres.md`, "Database UIs"). The owner keeps whichever of pgAdmin and CloudBeaver gets used more.

## Derived from

The sources and the versions read are in `NOTES.md`.

Dokploy's template was not read. Choices, the same as pgAdmin's (`apps/vps/pgadmin/README.md`):

- Tailnet only, through Traefik's `ipallowlist`, with the zone's wildcard certificate.
- The connection is added by hand once, in the UI: host `pg-proxy`, port `5436`, user `dbuser_owner`, database
  `postgres`. Its password is in OpenBao (`kv/general/pigsty`, field `pg_user_dbuser_owner`); do not save it in
  CloudBeaver.
- **"Show all databases"** is off by default, so only `postgres` appears. It is the provider property
  `@dbeaver-show-non-default-db@` on the connection; it is set in the workspace's
  `GlobalConfiguration/.dbeaver/data-sources.json` with CloudBeaver stopped (backup `data-sources.json.bak-20261109`
  beside it). A new connection needs it again.
- **Asleep when idle,** behind Sablier (`apps/vps/sablier/README.md`, "Making an app sleep"): stopped after 30 minutes
  without requests, started by the next one, which waits up to 2 minutes. The tailnet allowlist runs before Sablier's
  middleware, so a request from outside the tailnet gets 403 and wakes nothing.
- No backup: the workspace holds CloudBeaver's admin account and saved connections only.
- The auto-configuration works on 26.2.4: after the first start, its API reported `configurationMode` false, so
  no setup wizard.
