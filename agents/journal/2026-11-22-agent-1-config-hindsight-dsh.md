# 2026-11-22 — agent-1: the owner's agent config, Hindsight, DeepSeek Harness and the tailnet

**Who:** Claude Code (Opus 5.5), the owner  **Scope:** `agent-1`  **Mode:** write
**Task:** owner, in session: copy his agent config and Hindsight setup to every harness on agent-1, not
through Hindsight itself; install DeepSeek Harness; join the tailnet  **Skill:** none

## What changed

- From the owner's workstation, by `tar` over SSH (his private files, not in this repo): `~/.agents/`
  (`AGENTS.md`, 17 skills; the Omarchy ones left out), `~/.claude/CLAUDE.md`, links from Codex, pi,
  agy, OpenCode and omp to `~/.agents/AGENTS.md`, Claude's skill links, `~/.hindsight/coding-agent.json`.
- Hindsight: `npx @vectorize-io/hindsight-coding-agents@0.8.2 install all`, the workstation's version,
  wired Claude Code, Codex, OpenCode, OpenCode 2, pi, agy and DeepSeek Harness. 0.8.8 renamed the page
  tools and its OpenCode plugin reported "server does not support pages", so it was replaced. omp, a pi
  fork with no integration of its own, loads pi's (`extensions:` in `~/.omp/agent/config.yml`). Hermes
  uses its own `hindsight` plugin on the same server and bank, auto-recall off, and its `SOUL.md` points
  at `~/.agents/AGENTS.md` (DeepSeek Harness reads that file as its global instructions by itself).
- DeepSeek Harness 0.2.2-rc.5 by mise (`ansible/files/agent/mise-config.toml`; `prerelease = true`, as
  every release is one). `~/.dsh/cordis.patch.yml`: opencode-go with DeepSeek V4.1 Flash, Parallel's
  free search, and the credential store on (the headless profile ships it off).
- `ansible/files/agent/opencode.json` keeps Hindsight's plugin line, so a playbook run does not drop it.
- Orca skills updated to agent-1's Orca 1.4.269 (`orca skills update --all`).
- Tailnet: `tailscale up --advertise-tags=tag:agent` after the owner added the tag to the access policy.

## Snapshot / backup taken

None: configuration in the owner's home folder only.

## How it was verified

- Each harness's one-shot mode asked for the first Hindsight knowledge page: Claude Code, Codex, OpenCode
  2, pi, omp, agy and DeepSeek Harness answered "Homelab"; Hermes's `hindsight_recall` returned a memory.
  All eight named the bank (`aman-mem`) from their global instructions alone.
- Hermes first lacked `hindsight_client` in two of its environments; `hermes pm repair` fixed it.
- DeepSeek Harness's copied opencode-go key got 401; the key Hermes uses here works.
- `tailscale status`: tagged `tag:agent`; the Hindsight server answers over the tailnet.

## Still open

None of this outside `agent.yml` is reproducible from the repo yet; a skill or private script could do it.
