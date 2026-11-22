# 2026-11-22 — Add a PyPI remote to the LAN cache

**Who:** Claude Code (Opus 5.5)  **Scope:** Artifact Keeper on `cache-1`  **Mode:** write
**Task:** owner, in session: a PyPI remote, first meant for Hermes on agent-1; kept for later clients when
Hermes went to its own installer instead (owner, 2026-11-22)  **Skill:** `agents/skills/add-a-cache-remote/`

## What changed

- `apps/homeserver/artifact-keeper/Caddyfile`: `/pypi/*` to the backend, the prefix upstream's Caddyfile
  uses (`docker/Caddyfile` at commit `825b75e9`). Deployed with `ansible-playbook cache.yml`, which restarted
  Caddy.
- `remotes.txt`: `pypi`, format `pypi`, upstream `https://pypi.org`, 30 GB cap; `cache-remotes.sh` created it.

## Snapshot / backup taken

None: the cache's state is rebuilt from the repo (`agents/decisions/backup-tiers.md`, rebuildable state).

## How it was verified

- `cache.yml --check --diff` showed only the Caddyfile line; the run changed the file, the stack and Caddy.
- `cache-remotes.sh`: `pypi: created (200)`, cap 30 GB, the idle rule on 13 repositories.
- From agent-1: the HTML and JSON (PEP 691) indexes for `requests` answer 200, and the JSON lists
  `upload-time` per file. `pip download requests==2.32.3` through it twice (0.7 s, then 0.55 s) gave a wheel
  whose SHA-256 matches PyPI's. pip ignores a plain-HTTP index unless the host is in `trusted-host`.

## Still open

No machine uses it yet.
