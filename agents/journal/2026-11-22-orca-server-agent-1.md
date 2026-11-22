# 2026-11-22 — Run the Orca server on agent-1

**Who:** Claude Code (Opus 5.5)  **Scope:** `agent-1`, the owner's Orca on his workstation  **Mode:** write
**Task:** owner, in session: Orca headless on agent-1, installs and updates handled for him (plan step B0)
**Skill:** none

## What changed

- `ansible/agent.yml`: Orca's server-only build 1.4.269 (digest pinned) from the cache into
  `/opt/orca-server/1.4.269`, `current` pointing at it, `orca`/`orca-ide` in `/usr/local/bin`, lingering for
  `aman`, and the user unit `orca-serve.service` written by `orca-ide serve service install` (port 6768,
  `--refuse-public`). A drop-in adds the mise shims to its PATH and caps each terminal at 3G, no swap (a guess).
- `files/agent/orca-server-update.sh`, run every 6 hours by `orca-server-update.timer`: follows Orca's latest
  release through the cache and restarts the service only when no terminal is open. Orca cannot update a
  headless Linux server itself (`remoteUpdateSupport`: `unsupported-headless-serve`; paired-client updates are
  macOS only, `hasServeUpdateSupervisor` in stablyai/orca's `serve-update-handoff.ts`).
- The owner's Orca has agent-1 as a paired server (`orca environment add --name agent-1`), from an `orca pair`
  link passed straight to the workstation without being shown.

## Snapshot / backup taken

None: only new files, a user service and a timer; nothing on agent-1 holds data yet.

## How it was verified

- `--check --diff` read first; then a run (13 changed) and a second run (0 changed).
- On agent-1: the service is active on port 6768, `orca status` is `ready` on 1.4.269, and
  `orca agent installed` lists claude, codex, opencode, pi and omp.
- Update path: with the release relabelled 1.4.268, `orca-server-update` fetched 1.4.269 through the cache,
  checked it, moved `current` and restarted the service in 6 s, back `ready` on 1.4.269. Fake folder removed.
- From the workstation (Orca 1.4.264): `orca status --environment agent-1` is `ready`.
- Memory: systemd counts 584 MiB for the idle service, above a research worker's 100–250 MiB estimate.

## Still open

- The Orca test (`worker-start --on agent-1`, a read-only task) waits for the owner's harness sign-ins and a
  repository on agent-1. The updater's "terminals open" branch has not run yet.
- The phone (`orca pair --mobile` on agent-1) and re-pairing with the tailnet address once agent-1 joins.
