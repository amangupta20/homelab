# 2026-11-08 — Hermes WebUI: Hindsight plugin could not import its client

**Who:** Claude Code (Opus 5.5), from the workstation over SSH, on the owner's go-ahead  **Scope:** remote VPS, `hermes` project in Dokploy (containers `hermes-agent-webui`, `hermes-agent`)  **Mode:** write
**Task:** the owner: Hermes said "Hindsight is down"; find out why and fix it  **Skill:** none

## What happened

Hindsight itself was up (a Hindsight search from the workstation answered the
same hour). In the Hermes WebUI, every `hindsight_recall` / `hindsight_retain`
failed with `ModuleNotFoundError: No module named 'hindsight_client'`. A Hermes
session that diagnosed it found the first such error in its logs on
2026-10-18 (the Hermes session's report; not re-read here).

Why, as read on the live containers today:

- The WebUI server (`python server.py`) starts under `/app/venv`, where the
  image's `docker_init.bash` installs `hindsight-client` (startup log:
  `-- hindsight-client already installed`). A fresh `/app/venv/bin/python`
  imports it fine.
- The agent it runs (`nousresearch/hermes-agent:latest`, a package-manager or
  "PM" install, v0.21.6 and later) re-launches that process into the agent's
  own Python. `/app/managed_agent_startup.py` in WebUI image `0.52.651` imports
  the agent's `hermes_bootstrap` for this. After the re-launch, the process's
  executable is uv's CPython 3.14.10 and every compiled library it maps comes
  from the agent's `.venv/lib/python3.14/site-packages`
  (`sudo readlink /proc/<pid>/exe` and `/proc/<pid>/maps` on the host).
  `/app/venv` is no longer used, and the agent's venv had no `hindsight_client`.
- That venv lives in the `hermes_agent_src` volume, which the WebUI mounts
  read-only and `hermes-agent` mounts read-write at `/opt/hermes`
  (`docker inspect`). The agent image cannot carry plugin dependencies, so
  every new agent image brings back the same gap.

The same failure is open upstream: NousResearch/hermes-agent#144642 (runtime
imports only from the image's `.venv`; a root copy is the recovery and an image
update wipes it), #138220 (docker image's venv out of sync with `uv.lock`),
#132030 (plugin `pip_dependencies` never reach `uv.lock`), and
nesquena/hermes-webui#8849 (extras never reach the venv the WebUI runs). All
were open when read on 2026-11-08.

## What changed

Five package folders copied from the WebUI's `/app/venv` into the agent's venv
(`/opt/hermes/.venv/lib/python3.14/site-packages`, written through
`hermes-agent` because the WebUI's mount is read-only): `hindsight_client`,
`hindsight_client_api`, `hindsight_client-1.2.0.dist-info`, `aiohttp_retry`,
`aiohttp_retry-2.9.1.dist-info`. `aiohttp-retry` is a dependency of
`hindsight-client` that the agent's venv lacked; the rest (aiohttp, pydantic,
python-dateutil, typing-extensions, urllib3, yarl) were already there
(`METADATA` `Requires-Dist`, compared with the venv's `.dist-info` list).
Nothing existing was overwritten (`tar -xk`). Then `hermes-agent-webui` was
restarted; `hermes-agent` was not.

## Snapshot / backup taken

`tar` of the agent venv's whole `site-packages` before the copy, kept on the
VPS under `/home/ubuntu/backups/` (25,554 entries). Not restored, so not
verified as a backup; undoing the change is deleting the five folders.

## How it was verified

- As `hermeswebui`, the server's own interpreter with `-I` and only the agent's
  site-packages on its path: `import hindsight_client, hindsight_client_api,
  aiohttp_retry; from hindsight_client import Hindsight` printed `import ok`.
- After the restart: container `healthy` in about 45 s, and `hermes memory
  status` (which goes through the same re-launch) showed provider `hindsight`,
  `Status: available ✓`.
- Not yet checked: a real `hindsight_recall` from a WebUI chat.

## Still open

- The fix lasts only until the agent volume is re-seeded. The stack's Dokploy
  updater schedule (not in this repo) deletes and re-seeds `hermes_agent_src`
  from `nousresearch/hermes-agent:latest` whenever the digest changes. The
  Hermes session said it was paused; it was not: Dokploy's `schedule` table
  showed `hermes-stack-update` enabled, daily at 04:00 IST, and the script has
  no pause switch of its own (read 2026-11-08 01:02 IST). Before it runs again
  it needs to re-copy these packages and check the import, not only that the
  containers run.
- `install out of sync (venv: out of sync with uv.lock)` still prints on every
  `hermes` command; that is upstream #138220.
- The `hermes` stack and its updater are not in this repo
  (`decisions/open-questions.md`).
