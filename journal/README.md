# Journal — what happened

One dated entry per operation that changed something, per incident, and per
recon pass. It is the answer to "what did we do to this, when, and why?" — the
operations counterpart of git history.

Not every check gets an entry: a routine check that found nothing wrong is not
news. Write one when something changed, broke, or was learned.

Naming: `journal/YYYY-MM-DD-<what>.md` (`2026-11-02-recon-homeserver.md`), so
the folder sorts by date.

## Rules

- Written by whoever did the work, human or agent, at the end of the work.
- Entries are not edited later except to add a "Follow-up" note at the bottom.
- Facts learned go into their owner file (`inventory/`, `systems/`) in the same
  commit; the entry links them instead of being the only place they live.

## Template

```markdown
# YYYY-MM-DD — <what was done>

**Who:** <you | agent name>  **Scope:** <VM / service>  **Mode:** read-only | write
**Task:** <one line or link>  **Runbook:** <runbooks/<name>/ or "none">

## What changed

## Snapshot / backup taken
<Write tasks only: which one, and that it was verified.>

## How it was verified

## Still open
<Anything unresolved; contradictions also go to decisions/open-questions.md.>
```
