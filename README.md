# Homelab

My bare-metal homelab. One physical server runs many isolated VMs, so one
compromised service can't take down everything. The goal is that everything
important is reproducible from code, not hand-configured — it is not there
yet (see Status).

- Hypervisor: XCP-ng (type-1, runs directly on hardware). Think Proxmox
  alternative, Xen-based.
- Management UI: Xen Orchestra (called XO or XOA). Web UI for start/stop,
  snapshots, backups.
- VMs: one per job (storage, proxies, apps). Apps inside VMs run as Docker
  Compose stacks.
- Provisioning: OpenTofu defines the VM, cloud-init does its first boot
  (hostname, SSH keys, IP). Configuration after boot has no tool in this repo
  yet.
- Access: admin only over Tailscale (private mesh VPN). No SSH open to the
  internet.
- Edge: Cloudflare (filter) -> Nginx Proxy Manager (routing) -> containers.
  Fail2Ban blocks brute force at the firewall.

This repo is the source of truth going forward.

## Why this repo exists

The lab grew by hand over three years: containers clicked into a manager,
`.env` files copied to five checkouts, services nobody has touched since they
were set up. That worked while there was time to babysit it. This repo is the
record of what exists and why, so the lab can be rebuilt, reviewed, and handed
to an AI agent for routine maintenance without the agent having to guess — and
without it slowly rewriting the design into something nobody chose.

No secrets in this repo. Ever. Tokens, passwords, keys stay in a vault,
never in git. See `systems/openbao.md` for where they live.

## What's where

- `inventory/services.md` — every service, what it does, and whether it is healthy.
- `inventory/network.md` — IP layout and how traffic flows in.
- `systems/xcp-ng.md` — how VMs are protected, and the one
  rule that destroys VMs if you break it.
- `iac/` — OpenTofu code that creates VMs. Start with `iac/README.md`.
- `systems/backups.md` — what gets backed up, and what restore is still untested.
- `plans/migration.md` — what order the current migration runs in.
- `systems/openbao.md` — where secrets live and how to use them.
- `repo/secret-scanning.md` — the scan that blocks a commit or push carrying a secret.
- `decisions/` — what was decided and why, one file per decision, plus
  `decisions/open-questions.md`: everything undecided or unverified, in one list.
- `AGENTS.md` — instructions for AI agents working in this repo.

## How I run it

1. **Isolation first** — one VM per job, GPU passed through only where needed.
   A bad VM stays in its box.
2. **Rebuild, don't pet** — if a VM rots, recreate it from code rather than
   nurse it back.
3. **Zero-trust admin** — Tailscale only, least-privilege ACLs. Edge is
   filtered and logged.
4. **Backups that can restore** — a backup only counts when a test restore
   works. What is backed up and what is still untested:
   `systems/backups.md`.

## Status

Where it actually stands (October 2026):

- Documented: services, network, platform rules, backups, secret handling —
  from memory, not yet checked against the live lab.
- Guardrails working: secret scanning at commit, push and in CI; OpenTofu
  static checks in CI.
- Not yet true: no VM is defined in code (`vm.tf` is git-ignored), homeserver
  stacks live only in Portainer, OpenBao is not deployed, nothing configures
  a VM after first boot.

Migration in progress. Rule: no migration writes until snapshots are verified.
See `plans/migration.md`.
