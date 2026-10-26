---
name: write-a-skill
description: Use when adding a new skill to this homelab repo or changing an existing one — after a multi-step task the next agent should not have to rediscover, when the owner had to explain how to do something, or when your harness saved a skill or note outside the repo.
---

# Write a skill

**Status:** UNTESTED

## When to use

- You finished something that took several steps or some trial and error.
- The owner explained how to do something that is not written down yet.
- `mise run agents:link` reported a skill "written outside the repo".
- An existing skill was wrong or out of date when you followed it.

## How

1. **Check it does not exist already.** `ls skills/` and read the
   `description:` lines (`grep -h '^description:' skills/*/SKILL.md`). Extend
   an existing skill rather than writing a near-duplicate.
2. **Pick the kind.** A procedure that touches the lab is a *runbook*; how to
   use a tool or this repo is *know-how*. Both templates are in
   `skills/README.md`.
3. **Create the folder.** `skills/<name>/SKILL.md`, where `<name>` is
   lowercase letters, digits and hyphens, and the `name:` line matches the
   folder exactly.
4. **Write the description first.** It is the only part an agent sees before
   deciding to load the skill: say what it does *and when to use it*, with the
   words someone would use when they need it.
5. **Write the body.** Commands or exact UI paths; every command run once or
   marked UNTESTED; every fact with its source. Long reference material goes
   in a separate file next to `SKILL.md` and is linked from it.
6. **Keep it portable.** No harness-specific tool names or paths. Code that
   only works in one harness belongs in `agents/extensions/<harness>/`.
7. **Keep it public-safe.** No credentials, public IPs, domains or tailnet
   names — the commit hook blocks them (`repo/secret-scanning.md`), but write
   placeholders from the start. Credentials live in OpenBao
   (`systems/openbao.md`).
8. **List it** under "Skills" in `skills/README.md`.
9. **Make it visible to every harness:** run `mise run agents:link`; which
   harnesses need it and which do not is in `agents/README.md`.
10. **Commit it alone**, Status UNTESTED, and propose it in a pull request.

**Adopting a skill your harness wrote** (e.g. in `~/.hermes/skills/<name>/`):
move the folder into `skills/<name>/`, rewrite it to the template, strip
anything harness-specific, then run `mise run agents:link` — the harness's
copy becomes a link to the repo's.

**Changing an existing skill:** same steps, but the change is a proposal for
the owner (`AGENTS.md`, "What you may edit"). Say in the pull request what was
wrong when you followed it.

## Gotchas

- An agent that never loads your skill usually means the description is too
  vague. Name the situation, not the topic.
- A harness that does not see the skill at all: check `agents/README.md` for
  how that harness finds skills.
