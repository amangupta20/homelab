---
type: idea-index
tags:
  - ideas
  - index
---

# Ideas — researched, not scheduled

Designs worth trying once there is time or hardware for them. An idea has been
thought through far enough to know what it would take and what it would teach,
but nobody has committed to doing it. Nothing here describes the live lab.

How this folder relates to the others:

| Folder | Holds |
|---|---|
| `ideas/` | could do, someday; nothing is promised |
| `plans/` | will do, in this order, with gates |
| `systems/`, `inventory/` | is true now |
| `decisions/` | why it is the way it is |

**Promoting an idea:** when the owner decides to do it, write `plans/<what>.md`,
set the idea's Status to `promoted to plans/<what>.md` and keep the page — it
holds the research behind the plan. An idea that is ruled out stays too, with
Status `dropped` and the reason, so the next agent does not research it again.

**Who edits:** the owner adds ideas or asks an agent to write one up. Agents may
correct facts on a page and add sources; they never promote or drop an idea on
their own, and never start work from this folder.

Every page starts with a property block (the Obsidian view reads it); the
schema is in `repo/obsidian-view.md`, and `mise run check:properties` checks it.

Naming: `ideas/<what>.md`, lowercase with hyphens (`multi-site-postgres.md`).

## Template

```markdown
---
type: idea
status: "<idea | researched | promoted to plans/<x>.md | dropped>"
verified: "no (research only)"
tags:
  - idea
---

# <What>

**Status:** idea | researched | promoted to `plans/<x>.md` | dropped (<why>)
**In one line:** <what it is, for someone who has never heard of it>
**Why try it:** <what it would give the lab, or what it would teach>
**Needs first:** <hardware, money, or a plan that has to finish before this can start>

## Design sketch

## Risks and costs

## Promote when
<The condition that would turn this into a plan.>

## Sources
<Where the research came from: docs, a conversation, a test. Say what is unverified.>
```

## Ideas

None yet.
