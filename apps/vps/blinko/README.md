# Blinko

**Status:** not deployed. Its database and user exist on `pigsty-1` (`plans/shared-postgres.md`).
It is here to test the shared Postgres with an app nothing depends on (owner, 2026-11-06).

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| `blinkospace/blinko`: `docker-compose.yml` and `docker-compose.prod.yml` | `main`, 2026-11-06 | image, port 1111, environment, health check |

Dokploy's template was not read. Choices that differ from the sources:

- No bundled Postgres: `DATABASE_URL` points at the shared cluster.
- No published port: Traefik reaches it through the domain set in Dokploy.
- The `blinko` user uses PgBouncer's `session` mode (`ansible/pigsty/pigsty.yml.template`).
  `transaction` mode can break Prisma migrations (from memory, not tried). The Dokploy host's
  tailnet access reaches ports 5433 and 6432, not 5436.

## Public access

The owner chose a public domain on 2026-11-07, because the notes are not critical. Blinko's own
login is the only barrier, so: the first account to register becomes superadmin, so register as soon
as it is up; then turn off registration (`isAllowRegister`, seen in `server/routerTrpc/user.ts`) and
check that a sign-up is refused. Leave its plugin and MCP features off. Update it promptly.

## Backups

**UNTESTED.** Notes are in the shared cluster's backups. Uploads in `blinko-data` have no backup, which
is acceptable only while this is a test. To be added if it stays.
