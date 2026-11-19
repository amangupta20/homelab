# pg-proxy

One HAProxy container that gives apps on the VPS one address for the shared
Postgres: `pg-proxy:5432` on `dokploy-network` (`agents/plans/shared-postgres.md`,
"Proxy"). It forwards to Pigsty's primary service on pigsty-1 and keeps no data.

**Status:** running (`agents/journal/2026-11-09-deploy-pg-proxy.md`); Blinko
connects through it.

| Port | Goes to | For |
|---|---|---|
| 5432 | Pigsty's primary service (5433) on pigsty-1 | apps |
| 5436 | Pigsty's `default` service: the primary's Postgres without PgBouncer | the database UIs only (`apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`) |

- **Where:** remote VPS, deployed by Dokploy from `compose.yaml` here. Not published:
  every app on `dokploy-network` can reach it, and each database still needs
  its own password.
- **Data and backups:** none; it keeps no data.
- **Settings:** pigsty-1's address is a variable, not written here (tailnet
  addresses stay out of this repo).

## Pointing an app at it

Its database URL uses `pg-proxy:5432` instead of pigsty-1's address and port 5433, for example
`postgresql://<role>:<password>@pg-proxy:5432/<db>`. The app must be on `dokploy-network`.

Why it is built this way, what it was derived from and how it was tested:
`NOTES.md`.
