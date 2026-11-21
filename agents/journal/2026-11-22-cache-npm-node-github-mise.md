# 2026-11-22 — LAN cache: npm, Node, GitHub releases and mise's apt repository

**Who:** Claude Code (Opus 5.5)  **Scope:** `cache-1` (`apps/homeserver/artifact-keeper/`)  **Mode:** write
**Task:** owner, in session: the downloads agent-1 needs, through the cache (step B0)  **Skill:** `agents/skills/add-a-cache-remote/`

## What changed

- `Caddyfile`: `/npm/*` and `/general/*` now reach the backend. `ansible-playbook cache.yml` deployed it and restarted
  Caddy and Prometheus; the run also brought `compose.yaml` and `prometheus.yml` up to the repo, whose only
  differences were comment paths from the 2026-11-19 reorganisation (`--check --diff`, read first).
- `remotes.txt` and `cache-remotes.sh`: new remotes `npm` (30 GB), `nodejs` (generic, 10 GB), `github-releases`
  (generic, 30 GB) and `mise-apt` (15 GB). The 30-day idle rule now covers 11 repositories.
- Tried and dropped: `gh-apt` for `cli.github.com/packages`, refused by the backend's validation
  (`apps/homeserver/artifact-keeper/NOTES.md`, "Quirks").

## Snapshot / backup taken

None: a remote holds only a cache, and `cache-remotes.sh` recreates the settings (`agents/decisions/backup-tiers.md`).

## How it was verified

Two fetches each from `agent-1` (`curl`): npm metadata 5.2 s then 0.19 s and a tarball 0.48 s then 0.06 s;
Node 26.8.2's tarball 6.4 s then 0.39 s with the SHA-256 from `SHASUMS256.txt`; gh's `.deb` 133 s then 0.15 s with
GitHub's published digest; mise's `Release` 0.37 s then 0.007 s. Then `ansible/agent.yml` installed everything
through them (`agents/journal/2026-11-22-build-agent-1.md`).

## Still open

- GitHub CLI's apt repository cannot be a remote until the backend's check changes; not reported upstream yet.
