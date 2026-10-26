# Homelab

My bare-metal homelab. One physical server runs many isolated VMs, so one
compromised service can't take down everything. Everything important is
reproducible from code, not hand-configured.

- Hypervisor: XCP-ng (type-1, runs directly on hardware). Think Proxmox
  alternative, Xen-based.
- Management UI: Xen Orchestra (called XO or XOA). Web UI for start/stop,
  snapshots, backups.
- VMs: one per job (storage, proxies, apps). Apps inside VMs run as Docker
  Compose stacks.
- Provisioning: cloud-init for first boot (hostname, SSH keys, IP), Ansible
  and OpenTofu for everything after.
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
never in git. See `docs/secrets-openbao.md` for where they live.

## What's where

- `inventory/services.md` — every service, what it does, and whether it is healthy.
- `inventory/network.md` — IP layout and how traffic flows in.
- `platforms/xcp-ng-xen-orchestra.md` — how VMs are protected, and the one
  rule that destroys VMs if you break it.
- `iac/` — OpenTofu code that creates VMs. Start with `iac/README.md`.
- `ops/backup-restore.md` — what gets backed up, and what restore is still untested.
- `ops/migration.md` — what order the current migration runs in.
- `docs/secrets-openbao.md` — where secrets live and how to use them.
- `docs/secret-scanning.md` — the scan that blocks a commit or push carrying a secret.
- `decisions/` — what was decided and why, one file per decision, plus
  `decisions/open-questions.md`: everything undecided or unverified, in one list.
- `AGENTS.md` — instructions for AI agents working in this repo.

## How I run it

1. **Isolation first** — one VM per job, GPU passed through only where needed.
   A bad VM stays in its box.
2. **Rebuild, don't pet** — cloud-init boots it, Ansible configures it,
   Compose runs apps. If a VM rots, I recreate it.
3. **Zero-trust admin** — Tailscale only, least-privilege ACLs. Edge is
   filtered and logged.
4. **Backups that can restore** — a backup only counts when a test restore
   works. What is backed up and what is still untested:
   `ops/backup-restore.md`.

## Status

Migration in progress. Rule: no migration writes until snapshots are verified.
See `ops/migration.md`.
