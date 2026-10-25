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
- `AGENTS.md` — instructions for AI agents working in this repo.

## Quick look

| Service | What it is | State |
|---|---|---|
| TrueNAS VM | storage OS, file shares + backup target | stable, clean-import test still to do |
| Xen Orchestra | web UI to manage all VMs + backups | stable, alerts via ntfy |
| BorgWarehouse | web UI for Borg backups (app-level, inside apps) | stable on TrueNAS |
| ntfy | phone/push alerts for backups and deploys | stable |
| Nextcloud AIO | self-hosted Dropbox replacement | stable, full restore test still to do |
| Object storage lab | experiment with S3-compatible storage across sites | idea, not funded/built |

Details: `inventory/services.md`

## Network in 30 seconds

Private subnet `10.22.33.0/24`:

- `.1` — router
- `.254` — Docker/proxies host, also runs apt cache on port 3142
- `.160` — TrueNAS storage

All admin over Tailscale. Public web traffic comes in via Cloudflare, then
Nginx Proxy Manager, then to the right container.

Details: `inventory/network.md`

## How I run it

1. **Isolation first** — one VM per job, GPU passed through only where needed.
   A bad VM stays in its box.
2. **Rebuild, don't pet** — cloud-init boots it, Ansible configures it,
   Compose runs apps. If a VM rots, I recreate it.
3. **Zero-trust admin** — Tailscale only, least-privilege ACLs. Edge is
   filtered and logged.
4. **Backups that can restore** — XO image backups to TrueNAS, then offsite.
   Stateful apps get an extra app-level backup. A backup only counts when a
   test restore works.

## Status

Migration in progress. Rule: no migration writes until snapshots are verified.
See `ops/migration.md`.
