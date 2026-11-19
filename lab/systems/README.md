---
type: system-index
tags:
  - systems
  - index
---

# Systems — how each thing works

One page per thing you run, or per concern that spans several (backups). The
inventory row says *what and where*; this page says *how it works and what not
to do*.

Every page starts with a property block (the Obsidian view reads it); the
schema and rules are in `agents/obsidian/obsidian-view.md`, and `mise run check:properties`
checks it.

Naming: `lab/systems/<thing>.md`, lowercase, the name you would search for
(`truenas.md`, `edge.md` for Cloudflare + Nginx Proxy Manager, `vps.md`).

Create a page when there is something to say beyond the inventory row — not
before.

A page stays under 150 lines (`mise run check:docs`): how it works now, its
rules, its backups. Measurements, reasons, closed incidents, sketches and dates
go to `lab/systems/notes/<thing>.md`, linked from the page; split, never
delete. The check fails on a new date on a page (today's are on its allowlist).

## Template

```markdown
---
type: system
tags:
  - system
---

# <Thing>

<One line: what it is, for someone who has never heard of it.>

**Status:** <running | planned | broken | …> — <one line>. Row: `lab/inventory/services.md`.

## How it works

## Rules
<What must never be done, and why. Danger first.>

## Backups
<One line + link to `lab/systems/backups.md`; only what is specific to this thing.>

## Open questions
<Link to the matching section of `agents/decisions/open-questions.md`.>
```

## Pages

- `xcp-ng.md` — hypervisor and Xen Orchestra, and the rule that destroys VMs.
- `backups.md` — what is backed up, how, and which restores are untested.
- `vps.md` — the remote VPS, Dokploy, and what goes there.
- `openbao.md` — the secret store: where secrets live and how they are read.
- `oob.md` — the Raspberry Pi that is a second way into the home LAN, on its own tailnet.
- `truenas.md` — the storage VM: disks, pools, shares, snapshots, replication and its apps.
- `router.md` — the home router (OpenWrt on a Jio indoor unit), its Wi-Fi settings and the serial-only recovery.
