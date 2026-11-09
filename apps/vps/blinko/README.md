# Blinko

**Status:** running on the VPS since 2026-11-07, with its database on `pigsty-1`
(`plans/shared-postgres.md`, `journal/2026-11-07-deploy-blinko.md`). It is here to test the shared Postgres with an app nothing depends on (owner, 2026-11-06).

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| `blinkospace/blinko`: `docker-compose.yml` and `docker-compose.prod.yml` | `main`, 2026-11-06 | image, port 1111, environment, health check |

Dokploy's template was not read. Choices that differ from the sources:

- No bundled Postgres: `DATABASE_URL` points at the shared cluster through `pg-proxy:5432`
  (`apps/vps/pg-proxy/`), since 2026-11-09; before that, at pigsty-1's port 5433 directly.
- No published port: Traefik reaches it through the domain set in Dokploy.
- The `blinko` user uses PgBouncer's `session` mode (`ansible/pigsty/pigsty.yml.template`).
  `transaction` mode can break Prisma migrations (from memory, not tried). The Dokploy host's
  tailnet access reaches ports 5433 and 6432, not 5436.

## Public access

The owner chose a public domain on 2026-11-07, because the notes are not critical. Blinko's own
login is the only barrier. The first account to register becomes superadmin; after that, a sign-up
is refused unless `isAllowRegister` is true in its `config` table (`server/routerTrpc/user.ts`), and
that row does not exist here. Leave its plugin and MCP features off. Update it promptly.

## Backups

Notes are in the shared cluster's backups. Uploads and embeddings, in `blinko-data`, have no backup: the owner deferred
that until Garage is back, as they are not critical (2026-11-07).

## Sleeping

It stops after 20 minutes without traffic and starts on the next request, which then takes about 6.5 s (`journal/2026-11-07-deploy-sablier.md`).
Its scheduled jobs do not run while it is stopped. A deploy that recreates the container gives a few seconds of 500s, up to 30 s
(`apps/vps/sablier/README.md`).
