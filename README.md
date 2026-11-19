# Homelab

My bare-metal homelab. One physical server runs one VM per job, so one
compromised service can't take down everything; a small remote VPS runs the
public-facing apps. The goal is that everything important is rebuilt from code,
not hand-configured. Part of it is; the rest is documented here and migrates
one app at a time.

- Hypervisor: XCP-ng (type-1, runs directly on hardware; a Xen-based
  alternative to Proxmox), managed through Xen Orchestra (XO), a web UI for
  VMs, snapshots and backups.
- Provisioning: OpenTofu defines a VM, cloud-init does its first boot
  (hostname, SSH keys, IP), Ansible configures it after that. Apps inside VMs
  run as Docker Compose stacks.
- Access: admin only over Tailscale (private mesh VPN). No SSH open to the
  internet.
- Edge: Cloudflare (filter) -> Nginx Proxy Manager (routing) -> containers;
  Fail2Ban blocks brute force. Internal apps sit behind Traefik at
  `<app>.home.<zone>`.
- Remote VPS: apps deployed by Dokploy from the Compose files in `apps/vps/`.

**Never delete an XCP-ng base snapshot by hand** — it can corrupt the VM.
See `systems/xcp-ng.md`.

## What is in code

| Thing | Where | In code | Details |
|---|---|---|---|
| cache-1 (apt and container image cache) | VM, home | yes | `iac/cache-vm.tf`, `ansible/cache.yml`, `apps/homeserver/artifact-keeper/` |
| proxy-1 (Traefik for `*.home`) | VM, home | yes | `iac/proxy-vm.tf`, `ansible/proxy.yml`, `apps/homeserver/traefik/` |
| pigsty-1 (shared Postgres) | Oracle Cloud VM | yes | `iac/oci/`, `ansible/base.yml`, `ansible/pigsty/` |
| xo-ce (Xen Orchestra) | VM, home | Ansible only | `ansible/xcpng.yml` |
| oob-1 (out-of-band Raspberry Pi) | hardware, home | Ansible only | `ansible/oob.yml`, `systems/oob.md` |
| OpenBao, Authentik, Langfuse, Hermes WebUI, Blinko, pgAdmin, CloudBeaver, pg-proxy, Sablier | remote VPS (Dokploy) | Compose only | `apps/vps/` |
| The remote VPS itself | Oracle Cloud | no | `systems/vps.md`, `agents/decisions/vps-outside-opentofu.md` |
| Other VPS apps | remote VPS (Dokploy) | no | `inventory/services.md` |
| Home app stacks (Immich, Jellyfin, Nextcloud and others) | Portainer, several VMs | no | `inventory/services.md` |
| TrueNAS, Garage, backups | VM, home | no | `systems/truenas.md`, `systems/backups.md` |
| XCP-ng host | hardware, home | no | `systems/xcp-ng.md` |
| Router, DHCP, DNS | hardware, home | no | `systems/router.md` |

Hand-written from the files above; what runs and whether it is healthy is in
`inventory/services.md`. The migration plan is `agents/plans/home-overhaul.md`.

## Why this repo exists

The lab grew by hand over three years: containers clicked into a manager,
`.env` files copied to five checkouts, services nobody has touched since they
were set up. That worked while there was time to babysit it. This repo is the
record of what exists and why, so the lab can be rebuilt, reviewed, and handed
to an AI agent for routine maintenance without the agent having to guess — and
without it slowly rewriting the design into something nobody chose.

No secrets in this repo. Ever. Tokens, passwords, keys stay in a vault,
never in git. See `systems/openbao.md` for where they live.

## Find something

| I want to know… | Look in |
|---|---|
| what runs, where, and whether it is healthy | `inventory/services.md` |
| which machines exist | `inventory/hosts.md` |
| an IP, or how traffic gets in | `inventory/network.md` |
| how a thing works and what never to do to it | `systems/` — one page per thing (`xcp-ng.md`, `backups.md`, `openbao.md`) |
| what is backed up, and which restores are untested | `systems/backups.md` |
| how to do a task step by step | `agents/skills/` — runbooks and know-how, shared with the agent harnesses (`agents/`) |
| what is in progress | `agents/plans/` |
| what could be tried later (researched, not scheduled) | `agents/ideas/` |
| why something is the way it is | `agents/decisions/` |
| what is undecided or unverified | `agents/decisions/open-questions.md` |
| what was done, when, and by whom | `journal/` |
| a stack's Compose file | `apps/homeserver/`, `apps/vps/` |
| how VMs are created | `iac/README.md` |
| how a machine is configured after it boots | `ansible/README.md` |
| the tailnet's access rules | the private repo `homelab-private`, not this one |
| how this repo's checks work, setting up a checkout | `agents/review/` |
| a dashboard view of the lab (Obsidian) | `agents/obsidian/Home.md`, set up in `agents/obsidian/obsidian-view.md` |
| how an AI agent is expected to work here | `AGENTS.md` |
| how each agent harness gets the skills and rules | `agents/` |

Every folder has a README saying what goes in it and a template to copy.

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
