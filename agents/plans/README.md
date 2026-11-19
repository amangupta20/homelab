---
type: plan-index
tags:
  - plans
  - index
---

# Plans — work in flight

Multi-step work that is under way or next: migrations, moves, rebuilds. A plan
says where it is going, what gates each step, and how you know it is done. When
it is finished, the outcome lands in `lab/systems/` and `lab/inventory/`, the story in
`agents/journal/`, and the plan is marked done (kept, not deleted — it is history).

Every page starts with a property block (the Obsidian view reads it); the
schema and rules are in `agents/obsidian/obsidian-view.md`, and `mise run check:properties`
checks it.

Not scheduled yet? It belongs in `agents/ideas/` until the owner decides to do it;
a plan promoted from an idea links back to it.

Naming: `agents/plans/<what>.md` (`migration.md`, `portainer-to-git.md`, `vps-into-repo.md`).

## Template

```markdown
---
type: plan
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
- `home-overhaul.md` — moving every home workload to datasets per app, Arcane, Pangolin and new Docker VMs, in gated steps (in progress, A1 to A3 and B4a phase 1 done).
- `migration.md` — the earlier migration plan; replaced by `home-overhaul.md` on 2026-11-14.
- `shared-postgres.md` — one Pigsty-managed Postgres cluster on a second VPS then at home that apps share (in progress: installed on `pigsty-1`, drills done).
- `offsite-backups.md` — the encrypted offsite backup tier, OpenBao first (in progress).
- `hindsight-d1-reranker.md` — d1-2B on a homelab GPU VM, loaded on demand, in Hindsight's reranker chain (not started).
- `package-and-image-cache.md` — apt packages and container images cached once at home, inside a disk budget (in progress: Artifact Keeper picked for a month's trial, on the `main` image until a release has the byte cap).
- `ai-reviewer-prime-agent.md` — Prime Agent reviews the owner's pull requests with three levels of finding, memory and kept traces; built as a GitHub App on GitHub's runners instead of spot VMs (in progress, step 7; how it works: `agents/review/prime-reviewer.md`).
- `netbox.md` — NetBox as the lab's inventory, kept current by a sync from the live systems (not started, no date).
- `sablier-wakeups.md` — stop rarely used VPS apps when idle and start them on the next request; Blinko first (done 2026-11-07).
- `oci-state-backup.md` — a second copy of every OpenTofu root's state in Garage (done 2026-11-16).
