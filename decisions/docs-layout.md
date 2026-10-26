# Facts live in one owner file each; reasons live in decisions/

Decided: 2026-10-26. Status: in force.

## Why

The repo is meant to be maintained mostly by a cheaper AI agent, with the
owner doing the design. Cheap agents follow steps well but lose the bigger
picture, and the way that shows up is drift: a fact written in five places
gets updated in one, and the copies quietly disagree.

A first draft (October 2026) used a spec graph generated with ThinkRail
(JetBrains' spec-driven development tool): a goal, an architecture page, and
one "module" spec per area. It surfaced useful open questions, but each module
spec restated the facts already in the fact pages. One
correction to the state backup touched seven files. ThinkRail is also built for
specs that generate code; most work here is operations, where the thing that
drifts is the live lab, not code.

So the layout is:

| What | Where | Who edits |
|---|---|---|
| Facts: services, hosts, IPs, schedules | `inventory/`, `systems/`, `plans/`, `iac/README.md`, `repo/` — one owner per fact | agent, saying how it verified |
| Decisions and their reasons | `decisions/` | owner; agent proposes |
| Undecided or unverified | `decisions/open-questions.md` | agent appends, owner resolves |
| How agents work here | `AGENTS.md` | owner; agent proposes |

## Cost / what this rules out

- No machine-readable spec tree. The ThinkRail spec pages were removed; their
  open questions moved to `open-questions.md`, their goal to the README, and
  their invariants were already in `AGENTS.md`.
- Planned additions (runbooks written as agent skills, an operations journal)
  will get their own folders when they exist, not before.

## Where it lives

`README.md` ("What's where"), `AGENTS.md`.
