# 2026-11-09 — deployed pg-proxy

**Who:** the owner, with Claude Code  **Scope:** new Dokploy project `pg-proxy` on the Remote VPS  **Mode:** write
**Task:** the "Proxy" item of `plans/shared-postgres.md`  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- OpenBao: `kv/dokploy/pg-proxy`, field `pigsty_1_address`, holds pigsty-1's tailnet address.
- Dokploy: a new project `pg-proxy` with one Compose service from this repo's `main`, compose path
  `./apps/vps/pg-proxy/compose.yaml`, `autoDeploy` off, and `PIGSTY_1_ADDRESS` read from OpenBao.
  Created and deployed through the Dokploy MCP (`agents/mcp/dokploy`), driven over stdio from a script.
  `DOKPLOY_URL` is the Dokploy address without `/api`; with `/api` every tool answers "Resource not found".
- Dokploy's OpenBao secrets provider: the new project added to its assignments. The first deploy had stopped with
  `Vault provider "openbao" is not enabled for this project/environment` (trap added to `systems/openbao.md`).

## Snapshot / backup taken

None: a new stateless service; nothing that existed was changed apart from the provider's assignment list,
which only gained one entry. The provider's connection test passed after the change.

## How it was verified

- Before the first deploy, the rendered config in a throwaway container: health check passed, and a client got
  `fe_sendauth: no password supplied` through it (`apps/vps/pg-proxy/README.md`).
- After the deploy: the container is `healthy`, on `dokploy-network` only, reachable as `pg-proxy`, with no
  published port (`docker inspect`).
- From a throwaway `postgres:16` container on `dokploy-network`, Blinko's own login with the host changed to
  `pg-proxy:5432` returned `current_user` `blinko`, database `blinko`, `pg_is_in_recovery` false (the primary).

## Still open

- Blinko still connects to pigsty-1 directly; moving it to `pg-proxy:5432` is the next change.
- The backend check is TCP only (README); revisit in phase 2.
