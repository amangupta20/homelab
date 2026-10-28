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
schema and rules are in `repo/obsidian-view.md`, and `mise run check:properties`
checks it.

Naming: `systems/<thing>.md`, lowercase, the name you would search for
(`truenas.md`, `edge.md` for Cloudflare + Nginx Proxy Manager, `vps.md`).

Create a page when there is something to say beyond the inventory row — not
before.

## Template

```markdown
---
type: system
status: "<running | planned | broken | …>"
verified: "<yes | no | partially> (<how>)"
hosts:
  - <exact name from inventory/hosts.md>
tags:
  - system
---

# <Thing>

<One line: what it is, for someone who has never heard of it.>

**Status:** <running | planned | broken | …> — <one line>. Row: `inventory/services.md`.

## How it works

## Rules
<What must never be done, and why. Danger first.>

## Backups
<One line + link to `systems/backups.md`; only what is specific to this thing.>

## Open questions
<Link to the matching section of `decisions/open-questions.md`.>
```

## Pages

- `xcp-ng.md` — hypervisor and Xen Orchestra, and the rule that destroys VMs.
- `backups.md` — what is backed up, how, and which restores are untested.
- `vps.md` — the remote VPS, Dokploy, and what goes there.
- `openbao.md` — the secret store: where secrets live and how they are read.
