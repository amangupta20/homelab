# 2026-11-23 — agent-1: the fleet research toolchain, and a slow router path

**Who:** Claude Code (Opus 5.5)  **Scope:** `agent-1`; the home router (read-only)  **Mode:** write
**Task:** owner, in session (2026-11-22): move his fleet research workspace to agent-1 with what it needs,
then homelab, and check both behave as on his workstation  **Skill:** none

## What changed

- `ansible/agent.yml` and `files/agent/mise-config.toml`: the fleet research toolchain as on the owner's
  workstation: Deno 2, Rust 1.100, uv 0.13 and pnpm 12 by mise, bubblewrap and OpenJDK 21 from Debian.
  Java came from Debian because mise's Temurin downloads from GitHub, which stalled (below).
- Outside the repo, by hand: the owner's fleet workspace (165 git repos re-fetched on agent-1 at his exact
  commits, 0.57 GB of untracked files copied, no dependencies or build output), his `celld` 0.6.3 binary,
  his Paperclip gateway checkout and its credentials, `~/projects/.claude` and `~/projects/AGENTS.md`, and
  Claude Code's memory and session history for both projects.

## Snapshot / backup taken

None: packages and files in the owner's home folder only.

## How it was verified

- All 165 repos' `HEAD` match the workstation's; Claude Code given the same context-only prompt in
  `~/projects/homelab` and `~/projects/fleet` on both machines listed the same instruction files, memory
  entries, Hindsight tools and rules, and the same skills apart from the workstation's Omarchy ones.
- Measured from the owner's workstation (off the home network) and from agent-1: traffic through the router's
  Tailscale forwarding runs at about 0.1 MB/s with heavy retransmission, for both the subnet route into the
  LAN and the GitHub detour out of it (a GitHub release download from agent-1: 1.8 MB in 30 s); agent-1's
  own Tailscale address ran at 4–4.5 MB/s. The router showed no drops and an idle CPU; `mtu_fix` and SNAT
  were already on, and turning on UDP GRO forwarding on `wan` changed nothing (reverted).
- `agent.yml` against agent-1's Tailscale address: a run, then a second with 0 changed; deno 2.9.8, rustc
  1.100.0, uv 0.13.9, OpenJDK 21.0.13, pnpm 12.22, bubblewrap 0.12 and celld 0.6.3 answer `--version`.

## Still open

The router's slow Tailscale forwarding (subnet route and GitHub detour; `lab/systems/router.md`). Until it is
fixed, reach agent-1 by its Tailscale name from outside home.
