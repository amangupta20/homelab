# 2026-11-09 — deployed pgAdmin and CloudBeaver, tailnet only

**Who:** the owner, with Claude Code  **Scope:** pigsty-1 (one role), Dokploy projects `pgadmin`, `cloudbeaver`,
`pg-proxy` on the Remote VPS, Cloudflare DNS, the tailnet policy  **Mode:** write
**Task:** "Database UIs" in `plans/shared-postgres.md`  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- **pigsty-1:** role `dbuser_owner` (`dbrole_admin` and `blinko`, not a superuser), from the template through
  `render.sh` and `bin/pgsql-user pg-meta dbuser_owner` (twice: the first run lacked the `blinko` membership, and
  `blinko` refused it with "User does not have CONNECT privilege", because the database has `revokeconn`).
  Password in OpenBao `kv/general/pigsty`, field `pg_user_dbuser_owner`.
- **Tailnet policy (owner, private repo):** `tcp:5436` added to the `tag:db-client` → `tag:pigsty` grant, with a test.
- **pg-proxy:** redeployed with the `5436` frontend.
- **Dokploy:** projects `pgadmin` and `cloudbeaver`, Compose from this repo's `main`, `autoDeploy` off, env from
  OpenBao `kv/dokploy/pgadmin` and `kv/dokploy/cloudbeaver` (generated passwords). Both projects added to the OpenBao
  provider's assignments (`systems/openbao.md`). Created and deployed through the Dokploy MCP.
- **Cloudflare:** `pgadmin.<zone>` and `cloudbeaver.<zone>`, DNS-only `A` records to the VPS's tailnet address.

## Snapshot / backup taken

None: two new stateless apps and a new role. The nightly pgBackRest backup from 01:00 covered the cluster. The
Pigsty config on the node matched the repo before the change (`render.sh --check`).

## How it was verified

- Before writing the apps, a throwaway `traefik/whoami` router with the same `ipallowlist`: 200 over the tailnet,
  403 over the public address, 403 with `X-Forwarded-For` and `X-Real-Ip` forged to a tailnet address.
- From the VPS: pigsty-1's 5436 reachable, 5432 still not.
- From a container on `dokploy-network`: `dbuser_owner` through `pg-proxy:5436` reads Blinko's tables;
  `inet_server_port()` 5432 (Postgres itself, not PgBouncer); `pg_is_in_recovery` false. `rolsuper` false.
- Both UIs: 200 over the tailnet by name, 403 from the public address, the zone's wildcard certificate served.
  pgAdmin answered after about 30 s on its first start. CloudBeaver's API reported `configurationMode` false, so
  `CB_ADMIN_*` skipped the wizard. Both containers reach `pg-proxy:5436`.

## Still open

- The owner's own test: logging in to each UI and opening the database (credentials in OpenBao, `apps/vps/*/README.md`).
- The owner drops whichever UI gets used less.
