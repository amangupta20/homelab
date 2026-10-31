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

| Question it answers | Folder | Who edits |
|---|---|---|
| What exists? (lookup tables) | `inventory/` | agent, saying how it verified |
| How does a thing work, what never to do? | `systems/` | agent, saying how it verified |
| How do I do X? | `skills/` (agentskills.io `SKILL.md`, shared by every harness) | agent adds new ones; changes to existing ones are proposed |
| What is in flight? | `plans/` | agent updates status; owner sets goals |
| What could be tried later? | `ideas/` | owner adds or asks; agent corrects facts, never promotes |
| Why is it this way? | `decisions/` | owner; agent proposes |
| What is undecided or unverified? | `decisions/open-questions.md` | agent appends, owner resolves |
| What happened, when? | `journal/` | whoever did the work |
| What do the stacks look like? | `apps/<host>/<app>/` | agent, through review |
| How does this repo's tooling work? | `repo/` | agent, through review |
| How do agents work here? | `AGENTS.md` | owner; agent proposes |

Folders are sorted by the question a person has when they open the repo, not
by document type, because the first reader is the owner scrolling for
something. Every folder exists from the start with a README holding its rules
and a template, so a model picking up the work follows the structure instead
of inventing one.

## Cost / what this rules out

- No machine-readable spec tree. The ThinkRail spec pages were removed; their
  open questions moved to `open-questions.md`, their goal to the README, and
  their invariants were already in `AGENTS.md`.
- Empty folders (`journal/`, `apps/`) exist before their first
  file, holding only a README.

## Addendum 2026-10-28: the Obsidian view

The owner reads the repo through Obsidian, not only GitHub: the plain lab
pages were readable but did not feel like somewhere to browse, and earlier
Obsidian vaults died because they needed hand-kept notes. So the files stay
the same and gain a thin layer only Obsidian uses — a property block on every
page in `systems/`, `inventory/`, `plans/`, tables in `bases/`, and `Home.md`
as the Obsidian front page. Agents keep it current; the owner only reads.
How it works and its rules: `repo/obsidian-view.md`.

Cost: each property block restates its own page's status and verification,
and `hosts` restates host names from `inventory/hosts.md`. That is a second
copy, which this decision otherwise forbids; it is allowed because the copy
sits on the same page (or is a name the check verifies against the owner),
and the page body always wins. `.githooks/check-properties.py` catches a
broken shape in CI; it cannot catch a stale status.

## Addendum 2026-10-31: `ideas/` (proposed by an agent, at the owner's request)

Research for things to try once there is time or hardware (a database
replica on the VPS, for example) had nowhere to go: `plans/` promises the work
will happen in order, and `decisions/open-questions.md` is for what is unknown
about the lab as it is. Left in a chat or in memory, the research gets
redone. So `ideas/` holds designs that were researched but not scheduled. An
idea becomes a plan only when the owner decides, and the idea page stays as
the research behind it (`ideas/README.md`).

Cost: one more folder to keep honest. Nothing in it describes the live lab, so
an agent must never treat an idea page as a fact or start work from it.

## Where it lives

`README.md` ("Find something"), every folder's README, `AGENTS.md`,
`repo/obsidian-view.md`.
