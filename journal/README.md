# Journal — what happened

One dated entry for each of these, and nothing else:

- a change to the live lab — a server, VM, container or setting, whether or
  not a pull request went with it;
- an incident — something broke or was found broken;
- a restore test — the proof `systems/backups.md` and the plans ask for.

It answers "what did we do to the lab, when, and how did we check it?" —
what git history cannot show, because none of it is a file in this repo.

No entry for read-only checks or changes to this repo alone: facts found by a
check go into their owner file with their source ("verified: recon
2026-11-02"), and the pull request describes the repo change.

Naming: `journal/YYYY-MM-DD-<what>.md` (`2026-11-02-restore-test-openbao.md`),
so the folder sorts by date.

## Rules

- Written by whoever did the work, human or agent, at the end of the work.
- Entries are not edited later except to add a "Follow-up" note at the bottom.
- Facts learned go into their owner file (`inventory/`, `systems/`) in the same
  commit; the entry links them instead of being the only place they live.

## Template

```markdown
# YYYY-MM-DD — <what was done>

**Who:** <you | agent name>  **Scope:** <VM / service>  **Mode:** read-only | write
**Task:** <one line or link>  **Skill:** <skills/<name>/ or "none">

## What changed

## Snapshot / backup taken
<Write tasks only: which one, and that it was verified.>

## How it was verified

## Still open
<Anything unresolved; contradictions also go to decisions/open-questions.md.>
```
