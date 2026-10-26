# Skills — how to do X

Everything an agent (or you) needs to know how to do, one folder per skill, in
the open agentskills.io format. This folder is the only copy: every agent
harness reads it from here (`agents/README.md` says how), so a skill written
once works in Claude Code, Pi, omp, Codex, OpenCode, Hermes and whatever comes
next — on any machine that clones the repo.

Two kinds of skill live here:

- **Runbooks** — procedures that touch the lab: a restore test, moving a stack,
  adding a VM, the read-only recon pass. Use the runbook template.
- **Know-how** — how to use a tool or this repo: querying Xen Orchestra
  through its MCP server, writing a journal entry, adding a new skill. Use the
  know-how template.

```
skills/<name>/SKILL.md      the instructions (required)
skills/<name>/<file>        scripts, references or templates it uses (optional)
```

`<name>` is lowercase with hyphens and matches the `name:` line inside. The
`description:` line is what an agent reads to decide whether to load the
skill, so it says what the skill does *and when to use it*.

## Rules

- A runbook is **UNTESTED** until it has been followed once end to end. Its
  Status line then links the journal entry where that happened.
- Steps are commands or exact UI paths, not intentions ("click Backup ->
  Restore", not "restore the backup").
- Every write step says what to snapshot first, and every runbook ends with
  how to verify and a journal entry.
- Nothing harness-specific in a skill. If something only works in one
  harness, it is an extension (`agents/extensions/<harness>/`), not a skill.
- Agents may write new skills and propose fixes after using one; the owner
  merges them.

## Runbook template

```markdown
---
name: <name>
description: <What it does and when to use it, in one or two sentences.>
---

# <Title>

**Status:** UNTESTED | followed YYYY-MM-DD (`journal/<entry>.md`)
**Touches:** read-only | writes to <which VM/service>

## When to use / when not to

## Before you start
<Preconditions. For writes: which snapshot or verified backup to take first.>

## Steps
1. <command or exact UI path> — expect: <what you should see>

## Verify
<How to tell it worked.>

## Stop if
<Conditions that mean: stop, write down what you saw, ask the owner.>

## Afterwards
Write `journal/YYYY-MM-DD-<what>.md`.
```

## Know-how template

```markdown
---
name: <name>
description: <What it explains and when to use it, in one or two sentences.>
---

# <Title>

**Status:** UNTESTED | checked YYYY-MM-DD

## When to use

## How
<Commands, paths, examples. Every command run at least once or marked UNTESTED.>

## Gotchas
```

## Skills

None yet. First runbooks planned: the read-only recon pass, and moving one stack off
Portainer.
