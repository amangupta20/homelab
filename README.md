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
- Provisioning (intended, not in use yet): OpenTofu defines each VM and
  cloud-init does its first boot (hostname, SSH keys, IP). Today no VM is
  defined in code, and nothing configures a VM after boot
  (`decisions/open-questions.md`, Provisioning).
- Access: admin only over Tailscale (private mesh VPN). No SSH open to the
  internet.
- Edge: Cloudflare (filter) -> Nginx Proxy Manager (routing) -> containers.
  Fail2Ban blocks brute force at the firewall.
- Remote VPS: the public-facing apps, deployed by Dokploy. Part of this repo,
  not migrated in yet.

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

## Find something

| I want to know… | Look in |
|---|---|
| what runs, where, and whether it is healthy | `inventory/services.md` |
| which machines exist | `inventory/hosts.md` |
| an IP, or how traffic gets in | `inventory/network.md` |
| how a thing works and what never to do to it | `systems/` — one page per thing (`xcp-ng.md`, `backups.md`, `openbao.md`) |
| what is backed up, and which restores are untested | `systems/backups.md` |
| how to do a task step by step | `skills/` — runbooks and know-how, shared with the agent harnesses (`agents/`) |
| what is in progress | `plans/` |
| what could be tried later (researched, not scheduled) | `ideas/` |
| why something is the way it is | `decisions/` |
| what is undecided or unverified | `decisions/open-questions.md` |
| what was done, when, and by whom | `journal/` |
| a stack's Compose file | `apps/homeserver/`, `apps/vps/` |
| how VMs are created | `iac/README.md` |
| how this repo's checks work, setting up a checkout | `repo/` |
| a dashboard view of the lab (Obsidian) | `Home.md`, set up in `repo/obsidian-view.md` |
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

## Status

Where it actually stands (October 2026):

- Documented: services, network, platform rules, backups, secret handling —
  from memory, not yet checked against the live lab.
- Guardrails working: secret scanning at commit, push and in CI; OpenTofu
  static checks in CI.
- Not yet true: no VM is defined in code (`vm.tf` is git-ignored), homeserver
  stacks live only in Portainer, nothing configures a VM after first boot.

Migration in progress. Rule: no migration writes until snapshots are verified.
See `plans/migration.md`.
