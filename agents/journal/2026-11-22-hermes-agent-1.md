# 2026-11-22 — Install Hermes Agent on agent-1

**Who:** Claude Code (Opus 5.5)  **Scope:** `agent-1`  **Mode:** write
**Task:** owner, in session: install Hermes on agent-1 with its own installer, not Ansible or the LAN cache
(owner, 2026-11-22)  **Skill:** none

## What changed

- As `aman`: `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
  --skip-computer-use --non-interactive`. Hermes Agent v0.23.3, stable channel, a git install in
  `~/.hermes/hermes-agent` (2.7 GB in `~/.hermes`), `hermes` in `~/.local/bin`. No browser or computer use:
  agent-1 has Chromium and Playwright already. The setup wizard is skipped; `hermes setup` is the owner's.
- Not in `ansible/agent.yml` and not through the cache: the installer fetches uv, Python and its tools from
  GitHub and Nous's asset host, pinned by digest in its lock file, and its Python packages from PyPI (the
  cache's `pypi` remote held 12 entries afterwards). Updates are `hermes update`.

## Snapshot / backup taken

None: new files in the owner's home folder only.

## How it was verified

- The installer exited 0 ("Install complete").
- `hermes --version`: v0.23.3, stable, install method git.
- Orca on agent-1 lists `hermes` among its agents (`orca agent installed`).

## Still open

The owner's `hermes setup` (model provider and sign-in). Whether Hermes runs as an Orca worker or as a fleet
profile next to Orca is the owner's call.
