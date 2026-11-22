# 2026-11-22 — Build agent-1, the agent VM

**Who:** Claude Code (Opus 5.5)  **Scope:** XCP-ng host via Xen Orchestra (new VM only), `agent-1`  **Mode:** write
**Task:** owner, in session: step B0 of `agents/plans/home-overhaul.md`, first part  **Skill:** none

## What changed

- `iac/agent-vm.tf`: `agent-1`, cloned from the Debian 13 template onto `Nvme`: 4 vCPUs, dynamic memory
  256 MiB–4 GiB, 80 GB, UEFI with Secure Boot, `10.22.33.139` by cloud-init. Sizes are the owner's
  (2026-11-22); why the static maximum equals 4 GiB: the comment in that file.
- `ansible/inventory.yml`: `agent-1` in `xcpng` and `lan_cache_clients`. `common.yml`, `xcpng.yml` and
  `cache-client.yml` run on it: htop and btop, the XCP-ng guest agent, apt and Docker pointed at cache-1.

- `ansible/agent.yml` (same day): a full upgrade and one reboot (kernel 6.12.117), user `aman` (sudo without a
  password, Docker, the homelab VM key), Docker, Chromium 156, gh 2.105.0, Tailscale 1.104.7 (not joined) and
  mise 2026.11.12. mise installed Node 26.13.1, Claude Code 2.1.330, Codex 0.171.0, opencode 1.19.6, pi 1.6.0,
  Bun 1.4.5, oh-my-pi and Playwright 1.65.1 from the cache's npm remote. Hermes is not installed yet.
- The cache got four new remotes for this (`agents/journal/2026-11-22-cache-npm-node-github-mise.md`).

## Snapshot / backup taken

None: nothing existing was changed. The plan only added one resource; `run.sh` copied the new state to Garage
(`xcp-ng/20261121T192615Z.tfstate`).

## How it was verified

- `./run.sh plan` read before `apply`: 1 to add, 0 to change, 0 to destroy; the saved plan was applied.
- Over SSH: hostname `agent-1`, `eth0` at `.139/24`, 4 CPUs, about 3.9 GB of memory, a 74 GB root file system,
  Secure Boot enabled, `cloud-init status` done, Debian 13.
- The guest agent is active, and apt lists cache-1 first and Debian second.
- A second run of the three playbooks changed nothing, and two runs of `agent.yml` in a row changed nothing.
- As `aman` over SSH: every tool above answers `--version`; `sudo -n true` and `docker ps` work.

## Still open

The rest of B0 (`agents/plans/home-overhaul.md`): Hermes, the harness sign-ins (the owner's), the on-demand
desktop, the tailnet (`tag:agent`; the owner approves its sign-in), the OpenBao policy, backups, the Orca test.

**Follow-up (2026-11-22):** OpenCode 2 (`@opencode/cli` 2.3.2, `opencode` and `opencode2`) replaced opencode
1.19.6 at the owner's request, as on his workstation (`mise uninstall npm:opencode-ai --all`); a rerun changed nothing.
