# CloudBeaver

**Status:** running since 2026-11-09 (`journal/2026-11-09-deploy-db-admin-uis.md`). A web UI for the shared Postgres, reachable from the tailnet only
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
- No backup: the workspace holds CloudBeaver's admin account and saved connections only.
- The auto-configuration works on 26.2.4: after the first start, its API reported `configurationMode` false, so
  no setup wizard (2026-11-09).
