# 2026-11-07 — deployed Blinko on the shared Postgres

**Who:** the owner, with Claude Code  **Scope:** new Dokploy project `blinko`, database `blinko` on `pigsty-1`  **Mode:** write
**Task:** step 5 of `plans/shared-postgres.md`, as a test app  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- New Dokploy project with a Compose service from this repo (`apps/vps/blinko/`), created through
  Dokploy's API, with `autoDeploy` off. The owner assigned the OpenBao provider to the project in the UI, because the
  API needs the provider's token re-sent and only returns it masked.
- A public domain, on an existing wildcard DNS record. Blinko's own login is the only barrier (README).

## Snapshot / backup taken

None: a new app that touches nothing existing. Its database is in the cluster's backups. Its upload volume
has no backup.

## What went wrong

The first health check called `localhost`, which resolves to `::1` in the container, while the app listens on
IPv4 only. Docker marked it unhealthy and Traefik answered 404. Fixed by calling `127.0.0.1`.

## How it was verified

- The owner registered and logged in. The container is healthy, on image `1.8.9`.
- A sign-up with a test name from outside the tailnet got `not allow register`, and `accounts` still has one row.
- Through PgBouncer's port 5433 in session mode, its migrations made 23 tables (10 MB).
- HTTP redirects to HTTPS, with a Let's Encrypt certificate.
- `pgbackrest check` passed afterwards.

## Still open

- No test yet of restoring Blinko's own data from the cluster's backup.
- Whether other apps on `dokploy-network` expose anything to it without a login.
- 2FA on the owner's account is the owner's to turn on.
