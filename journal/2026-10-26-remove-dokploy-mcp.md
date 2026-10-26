# 2026-10-26 — removed the shared Dokploy MCP server from the VPS

**Who:** Claude Code (Opus 5.5), asked by the owner  **Scope:** remote VPS, Dokploy service `openwebui/dockploymcp`  **Mode:** write
**Task:** the owner: drop the shared MCP altogether; Hermes and Open WebUI no longer need it  **Skill:** none

## What changed

Deleted the Dokploy Compose service that ran `@dokploy/mcp` in HTTP mode for
Open WebUI and Hermes. It had no authentication of its own and held a Dokploy
API key. Agents and Hermes now run the MCP themselves (`npx @dokploy/mcp`)
with their own Dokploy API key, so no shared server holds one.

## Snapshot / backup taken

The service kept no data. Its Compose file and `.env` were copied from
Dokploy's checkout on the VPS to the owner's workstation before the delete
(not in this repo: the `.env` holds the API key).

## How it was verified

After the delete, on the VPS: no container of the service in `docker ps -a`,
its checkout folder gone from `/etc/dokploy/compose/`, nothing listening on
its port, and no row for it in Dokploy's `compose` table (22 Compose services
left).

## Still open

- Revoke the API key the removed service used, in Dokploy's settings (owner).
- Give each agent its own Dokploy API key, kept in its environment until
  OpenBao runs.
