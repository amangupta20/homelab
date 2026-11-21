# 2026-11-22 — Build agent-1, the agent VM

**Who:** Claude Code (Opus 5.5)  **Scope:** XCP-ng host via Xen Orchestra (new VM only), `agent-1`  **Mode:** write
**Task:** owner, in session: step B0 of `agents/plans/home-overhaul.md`, first part  **Skill:** none

## What changed

- `iac/agent-vm.tf`: `agent-1`, cloned from the Debian 13 template onto `Nvme`: 4 vCPUs, dynamic memory
  256 MiB–4 GiB, 80 GB, UEFI with Secure Boot, `10.22.33.139` by cloud-init. Sizes are the owner's
  (2026-11-22); why the static maximum equals 4 GiB: the comment in that file.
- `ansible/inventory.yml`: `agent-1` in `xcpng` and `lan_cache_clients`. `common.yml`, `xcpng.yml` and
  `cache-client.yml` run on it: htop and btop, the XCP-ng guest agent, apt and Docker pointed at cache-1.

## Snapshot / backup taken

None: nothing existing was changed. The plan only added one resource; `run.sh` copied the new state to Garage
(`xcp-ng/20261121T192615Z.tfstate`).

## How it was verified

- `./run.sh plan` read before `apply`: 1 to add, 0 to change, 0 to destroy; the saved plan was applied.
- Over SSH: hostname `agent-1`, `eth0` at `.139/24`, 4 CPUs, about 3.9 GB of memory, a 74 GB root file system,
  Secure Boot enabled, `cloud-init status` done, Debian 13.
- The guest agent is active, and apt lists cache-1 first and Debian second.
- A second run of the three playbooks changed nothing.

## Still open

The rest of B0 (`agents/plans/home-overhaul.md`): Docker and the harnesses, the on-demand desktop, the tailnet
(`tag:agent`; the owner approves its sign-in), the OpenBao policy, backups, and the Orca test.
