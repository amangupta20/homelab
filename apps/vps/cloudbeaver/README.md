# CloudBeaver

**Status:** written 2026-11-09; not deployed yet. A web UI for the shared Postgres, reachable from the tailnet only
(`plans/shared-postgres.md`, "Database UIs"). The owner keeps whichever of pgAdmin and CloudBeaver gets used more.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| CloudBeaver source: `CBConstants.java`, `CBApplication.performAutoConfiguration` | `main`, 2026-11-09 (tags are named differently from the image) | `CB_SERVER_NAME`, `CB_ADMIN_NAME`, `CB_ADMIN_PASSWORD` skip the setup wizard on the first start |
| `dbeaver/cloudbeaver` on Docker Hub | `26.2.4`, 2026-11-09 | arm64 image, port 8978, `/opt/cloudbeaver/workspace` |

Dokploy's template was not read. Choices, the same as pgAdmin's (`apps/vps/pgadmin/README.md`):

- Tailnet only, through Traefik's `ipallowlist`, with the zone's wildcard certificate.
- The connection is added by hand once, in the UI: host `pg-proxy`, port `5436`, user `dbuser_owner`, database
  `postgres`. Its password is in OpenBao (`kv/general/pigsty`, field `pg_user_dbuser_owner`); do not save it in
  CloudBeaver.
- **"Show all databases"** is off by default, so only `postgres` appears. It is the provider property
  `@dbeaver-show-non-default-db@` on the connection; on 2026-11-09 it was set in the workspace's
  `GlobalConfiguration/.dbeaver/data-sources.json` with CloudBeaver stopped (backup `data-sources.json.bak-20261109`
  beside it). A new connection needs it again.
- **Asleep when idle,** behind Sablier (`apps/vps/sablier/README.md`, "Making an app sleep"): stopped after 30 minutes
  without requests, started by the next one, which waits up to 2 minutes. The tailnet allowlist runs before Sablier's
  middleware, so a request from outside the tailnet gets 403 and wakes nothing.
- No backup: the workspace holds CloudBeaver's admin account and saved connections only.
- **UNTESTED:** whether the auto-configuration still applies to 26.2.4 as read from `main`. If the wizard appears on
  the first visit, the variables were ignored; finish the wizard with the same values.
