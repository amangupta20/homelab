# Agents — how every harness gets this repo's skills and rules

This repo is meant to be worked on by several agent harnesses — Claude Code,
Pi, omp, Codex, OpenCode, Hermes, and whatever gets tried next — on more than
one machine. None of them owns anything: the instructions (`AGENTS.md`) and the
skills (`skills/`) live in the repo, and each harness is pointed at them. On a
fresh clone, harnesses that read project folders see them at once; harnesses
that only read a home-directory folder need one `mise run agents:link`.

## How each harness finds the skills

| Harness | Reads skills from | How it gets there | Checked |
|---|---|---|---|
| Pi | `.agents/skills/` (project) | committed link to `skills/` | Pi 1.4.0 listed `write-a-skill`, 2026-10-26 |
| omp | `.agents/skills/`, `.claude/skills/` (project) | committed links | paths found in the omp binary, 2026-10-26; not run yet; may list each skill twice |
| Claude Code | `.claude/skills/` (project) | committed link to `skills/` | a running session picked up `write-a-skill`, 2026-10-26 |
| Codex, OpenCode, Gemini / Antigravity | `.agents/skills/` (project) | committed link | not checked: the agentskills.io convention |
| Hermes | `~/.hermes/skills/` (home directory only) | `agents/link.sh` | third-party guides; confirm on the agent VM |

The project links work as soon as the repo is cloned. Harnesses that only read
a folder in your home directory are listed in `agents/harnesses.txt` and need
one command per machine:

```bash
mise run agents:link    # or: sh agents/link.sh
```

(Run 2026-10-26 on a machine without Hermes: it reported Hermes as not
installed and changed nothing.)

Pi may ask you to trust the project before it loads project files; that is
expected, not an error. (Pi 1.4.0 `docs/configuration.md` says project
configuration loads after project trust; the check in the table used Pi's
`--approve` flag, so the prompt itself has not been seen yet.)

## How each harness finds the rules

`AGENTS.md` at the root. Harnesses that look for `CLAUDE.md` instead get a
one-line `CLAUDE.md` that points at it — one copy of the rules, never two.

## Adding a harness

1. If it reads `.agents/skills/` or `.claude/skills/` in the project: nothing
   to do. Add it to the table above with how you checked.
2. If it only reads a folder in your home directory: add a line to
   `agents/harnesses.txt` and run `mise run agents:link`. Use `adopt` if it
   writes skills on its own.
3. If it needs harness-specific code (an extension, a plugin): put it in
   `agents/extensions/<harness>/`.

## Not here

- Each harness's own memory, sessions and settings stay in its home directory
  and are not a source of truth. Facts an agent learns go into the repo.
- Credentials never: they come from OpenBao (`systems/openbao.md`) or the
  environment.
## Shared MCP servers

Shared MCP server launchers live in `agents/mcp/`.

- **Dokploy (`agents/mcp/dokploy`):** launches `@dokploy/mcp@0.30.7` over stdio.
  It fetches a scoped agent API key from OpenBao (`kv/general/dokploy`, field
  `api_key`). In line with `decisions/agent-access.md`, the key is restricted to
  app operations and cannot modify backup schedules or delete backups on Garage
  S3. Verified 2026-10-29: launched over stdio and listed tools successfully.
  Requires `DOKPLOY_URL` in the environment (e.g. `http://<tailscale-ip>:3000`,
  configured per machine, not in git).
  - Claude Code: add to local harness config (e.g. project `.mcp.json`, not committed):
    ```json
    {
      "mcpServers": {
        "dokploy": {
          "command": "./agents/mcp/dokploy",
          "env": {
            "DOKPLOY_URL": "http://<tailscale-ip>:3000"
          }
        }
      }
    }
    ```
  - Hermes / other harnesses: run `./agents/mcp/dokploy` with `DOKPLOY_URL` in
    the environment.
