# Runbooks — how to do X

Step-by-step procedures for recurring operations: a restore test, moving a
stack, adding a VM, the read-only recon pass. Written once by someone who
knows the lab, then followed by whoever does the work — you or the agent.

Each runbook is also an agent skill in the open agentskills.io format, so the
maintenance agent can load it without a second copy. That is why each one is a
folder with a fixed file name:

```
runbooks/<name>/SKILL.md      the procedure (required)
runbooks/<name>/<script>.sh   helper scripts it calls (optional)
```

`<name>` is lowercase with hyphens and matches the `name:` line inside.

## Rules

- A runbook is **UNTESTED** until it has been followed once end to end. Its
  Status line then links the journal entry where that happened.
- Steps are commands or exact UI paths, not intentions ("click Backup ->
  Restore", not "restore the backup").
- Every write step says what to snapshot first, and every runbook ends with
  how to verify and a journal entry.
- Agents may propose fixes to a runbook after using it; the owner merges them.

## Template

```markdown
---
name: <name>
description: <What it does and when to use it, in one or two sentences. The agent reads only this line when deciding whether to load the runbook.>
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

## Runbooks

None yet. First planned: the read-only recon pass, and moving one stack off
Portainer.
