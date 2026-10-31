---
type: plan-index
tags:
  - plans
  - index
---

# Plans — work in flight

Multi-step work that is under way or next: migrations, moves, rebuilds. A plan
says where it is going, what gates each step, and how you know it is done. When
it is finished, the outcome lands in `systems/` and `inventory/`, the story in
`journal/`, and the plan is marked done (kept, not deleted — it is history).

Every page starts with a property block (the Obsidian view reads it); the
schema and rules are in `repo/obsidian-view.md`, and `mise run check:properties`
checks it.

Not scheduled yet? It belongs in `ideas/` until the owner decides to do it;
a plan promoted from an idea links back to it.

Naming: `plans/<what>.md` (`migration.md`, `portainer-to-git.md`, `vps-into-repo.md`).

## Template

```markdown
---
type: plan
status: "<not started | in progress (step N) | blocked | done>"
verified: "<yes | no | partially> (<how>)"
tags:
  - plan
---

# <What>

**Status:** not started | in progress (step N) | blocked on <x> | done YYYY-MM-DD

**Goal:** <one sentence>
**Done when:** <a check someone can run, not a feeling>

## Steps
1. <step> — gate: <what must be true before the next step starts>

## Links
<systems pages, decisions, open questions this depends on>
```

## Plans

- `vps-foundations.md` — OpenBao and SSO on the VPS, before any further VPS app.
- `migration.md` — the current migration, in order, and the Portainer -> git target.
- `shared-postgres.md` — one Pigsty-managed Postgres at home that apps share (not started).
- `offsite-backups.md` — the encrypted offsite backup tier, OpenBao first (in progress).
- `hindsight-d1-reranker.md` — d1-2B on a homelab GPU VM, loaded on demand, in Hindsight's reranker chain (not started).
