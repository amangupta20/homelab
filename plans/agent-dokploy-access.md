# Agent access to Dokploy without delete rights

**Status:** not started — handoff written 2026-10-27. No agent has Dokploy
access today.

**Goal:** agents (Claude Code, Hermes, any harness) work with Dokploy through
the Dokploy MCP server run locally with `npx`, each with its own API key from
a Dokploy user that cannot delete anything and cannot reach backups.
**Done when:** an agent session lists the Dokploy projects it is allowed to
see, and an attempt to delete a service and to list or change backup
destinations is refused; the setup is in `agents/` and every harness that
needs it is listed there.

## Why it looks like this

- The shared Dokploy MCP server that ran on the VPS was removed on 2026-10-26
  (`journal/2026-10-26-remove-dokploy-mcp.md`). Its HTTP mode has no
  authentication of its own and holds a single Dokploy key for every caller
  (`src/http-server.ts`, `src/utils/clientConfig.ts` in
  github.com/Dokploy/mcp, v0.30.7). Running it locally over stdio
  (`npx @dokploy/mcp`) instead means the key stays with the agent that uses
  it, and each agent's key can be revoked on its own.
- `decisions/agent-access.md` allows agents convenient access, with one hard
  guard that matters here: an agent's credentials must not be able to delete
  or overwrite backups. An admin's Dokploy API key can, so the key must come
  from a limited Dokploy user, and that limit must be tested, not assumed.

## Steps

1. **A limited Dokploy user**, by the owner in the Dokploy UI (Settings →
   Users; **UNTESTED** labels — check them against the running version,
   which the owner keeps on the latest release): invite a member, e.g.
   `agent`, with API access on, creating services on, deleting projects and
   services off, Docker, SSH key and Git provider access off, and access only
   to the projects agents should touch. — gate: the member exists and its
   permissions are as listed (screenshot or read-back in the UI).
2. **Its API key**, created by the owner while logged in as that member, and
   stored in OpenBao at `kv/homelab/dokploy/agent` (field `key`), not in any
   file in this repo or typed into an agent session. One key per agent
   harness if they should be revocable separately (e.g. `.../agent-hermes`).
   — gate: `bao kv get -field=key kv/homelab/dokploy/agent` works from the
   owner's terminal.
3. **Prove the limit**, before any agent uses the key. With the key, call
   Dokploy's API read-only over the tailnet and expect refusals for
   backup-related calls: `destination.all`, a `backup.*` read, and
   `compose.delete` on a throwaway service in an allowed project. If the key
   can list, change or delete destinations or backups, or delete services:
   stop, revoke the key, and fix it with the owner in session — this is a
   security finding and does not go into the repo until fixed (`AGENTS.md`).
   — gate: every forbidden call refused, recorded in the PR (not the
   responses' data).
4. **Shared MCP definition** in `agents/mcp/` (the place `agents/README.md`
   reserves for it): a small launcher script that reads the key from OpenBao
   at start and runs the pinned package, so no key sits in a config file:

   ```sh
   #!/bin/sh
   # agents/mcp/dokploy — UNTESTED sketch
   DOKPLOY_API_KEY=$(bao kv get -field=key kv/homelab/dokploy/agent) || exit 1
   export DOKPLOY_API_KEY DOKPLOY_URL="${DOKPLOY_URL:?set DOKPLOY_URL}"
   export DOKPLOY_REDACT_ENV=true
   exec npx -y @dokploy/mcp@0.30.7
   ```

   `DOKPLOY_URL` is Dokploy's address over the tailnet (`http://<VPS tailnet
   IP>:3000`), set per machine like `BAO_ADDR` (`systems/openbao.md`, "Daily
   use") — it identifies the tailnet, so it is not written in the repo.
   `DOKPLOY_ENABLED_TAGS` can narrow the tools further. Pin the package
   version; the removed server ran it unpinned with `pull_policy: always`.
   Then the per-harness wiring: Claude Code reads a project `.mcp.json` whose
   server command is that script; other harnesses as `agents/README.md`
   describes. Hermes runs the same launcher inside its container, with its
   own key. — gate: a new agent session sees the Dokploy tools.
5. **Close out:** `agents/README.md` (the MCP definition, how each harness
   loads it, how it was checked), `systems/vps.md` ("Agents will reach
   Dokploy…" becomes present tense), and a skill change if
   `skills/deploy-on-dokploy/` can now do its Dokploy steps through the MCP.

## Open before starting

- Whether a Dokploy member can be kept away from backups and destinations at
  all. If Dokploy has no such permission, the options go back to the owner:
  no agent key, or a key for read-only work only.
- Whether `npx` is available on every agent machine (Node is installed
  through mise on the owner's workstation; the agent VM is not built).

## Links

`decisions/agent-access.md`, `journal/2026-10-26-remove-dokploy-mcp.md`,
`agents/README.md`, `systems/vps.md`, `systems/openbao.md`.
