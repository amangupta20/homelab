# pg-proxy

**Status:** running since 2026-11-09 (`journal/2026-11-09-deploy-pg-proxy.md`); Blinko connects through it since the same day. One HAProxy container that gives apps on the VPS one address for
the shared Postgres, `pg-proxy:5432` on `dokploy-network` (`plans/shared-postgres.md`, "Proxy"). It keeps no data.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| HAProxy configuration manual (`docs.haproxy.org/3.2/configuration.html`) | 3.2, 2026-11-09 | `mode tcp`, the timeouts, `clitcpka`/`srvtcpka`, `dontlog-normal`, server `check` options |
| Pigsty's service ports (`plans/shared-postgres.md`, "What the node and Pigsty's docs say") | as installed 2026-11-06 | port 5433, the primary service on each node |
| `haproxy` image on Docker Hub | `3.2.26-alpine`, 2026-11-09 | runs as `haproxy` (uid 99); BusyBox `nc` is in the image |

Dokploy has no HAProxy template (`blueprints/` in `Dokploy/templates`, 2026-11-09). Choices:

- **Forwards to Pigsty's 5433, not to Postgres directly.** Each Pigsty node runs its own HAProxy, which health-checks
  Patroni and sends 5433 to whichever node is primary. This one only has to reach a live node. With one node it is
  a fixed address; in phase 2 the second node becomes a second `server` line.
- **The backend check is a plain TCP check.** It shows that Pigsty's HAProxy answers, not that a primary exists.
  Enough for one node; revisit in phase 2.
- **Idle timeouts of 30 minutes, with keepalives,** because apps keep pooled connections open between queries.
  The value is a guess.
- **pigsty-1's address is a variable:** containers here cannot resolve tailnet names (`getent hosts pigsty-1` in a
  container on `dokploy-network` returned nothing, 2026-11-09), and tailnet addresses stay out of this repo.
- **On `dokploy-network`, not published.** Every app on that network can reach it; each database still needs its
  own password.

## Tested before the first deploy

On 2026-11-09, this file's rendered config in a throwaway `haproxy:3.2.26-alpine` container on `dokploy-network`:
the `nc` health check passed, and `psql -h <container> -U blinko` from another container there got
`fe_sendauth: no password supplied`, so the path reaches the database. The container was removed.

## The admin port, 5436

`pg-proxy:5436` goes to Pigsty's `default` service on pigsty-1, which is the primary's Postgres without PgBouncer.
It is for the database UIs only (`apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`): PgBouncer lists only the app
databases and users, and refuses `dbuser_dba` from the tailnet. Needs the tailnet rule for `tag:db-client` to
`tag:pigsty` to include `tcp:5436` (policy in the private repo; added by the owner 2026-11-09). Apps stay on 5432.

## Pointing an app at it

Its database URL uses `pg-proxy:5432` instead of pigsty-1's address and port 5433, for example
`postgresql://<role>:<password>@pg-proxy:5432/<db>`. The app must be on `dokploy-network`.
