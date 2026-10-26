# Review checklist

What a reviewer checks before a change reaches `main`. Written for an AI
reviewer (a subagent in whatever harness made the change, or the review job in
CI), and readable by a person doing the same review by hand.

The reviewer reads the full diff, `AGENTS.md`, and the README of every folder
the diff touches. It reports; it does not fix.

## Where it runs

- **Before a pull request:** the agent that made the change runs a separate
  reviewer subagent with this file (`AGENTS.md`, "Before you open a pull
  request"). Fast feedback, not enforced.
- **On every pull request:** `.github/workflows/review.yml` sends the diff,
  the commits, this file, `AGENTS.md` and the touched folders' READMEs to a
  model, and fails the `ai review` check unless the verdict is `approve`. That
  check is required on `main`. The workflow, script and this checklist always
  come from `main`, never from the pull request, so a change to any of them
  takes effect only after it merges — and the pull request that makes it is
  reviewed by the old version.

The CI reviewer is configured in the repository settings (Settings -> Secrets
and variables -> Actions), never in code:

| Name | Kind | Example |
|---|---|---|
| `REVIEW_API_URL` | variable | any OpenAI-compatible base URL, e.g. `https://api.deepseek.com/v1` |
| `REVIEW_MODEL` | variable | a model id at that provider |
| `REVIEW_API_KEY` | secret | the provider's API key |

Until all three are set, the check fails with "not configured" — it never
passes by default.

## 1. Nothing that should not be public

The scan (`repo/secret-scanning.md`) catches credentials, public IPs, tailnet
names and the domains on a local list. A reviewer catches what a pattern
cannot:

- a real domain, hostname, username, email address, serial number or MAC
  address that identifies the owner or the lab;
- a raw dump (`docker ps`, a router export, a full config) pasted instead of a
  summary;
- a list of what is exposed together with its version, or a weakness that is
  not yet fixed, described in enough detail to exploit.

## 2. True, and says how it is known

- Every fact added names its source (command, UI page, or "from memory,
  unverified"). A number nobody measured is labelled a guess.
- Every command added was run, or is marked **UNTESTED**.
- Nothing is invented to fill a gap — a missing reason stays marked missing.
- Nothing states as fact what `decisions/open-questions.md` lists as open,
  unless the same change resolves the question there.
- The repo leads the lab: a stack, config or decision has to merge before it
  can be deployed or put in force, so a change may describe something the
  live lab does not have yet. That is not a contradiction as long as the
  change says so ("not deployed", "planned", "proposed"). Stating it as
  already live is.

## 3. One fact, one owner

- No fact is copied into a second file; other files link to the owner.
- New pages follow the template in their folder's README and open with what
  the thing is and a **Status:** line.
- Every path mentioned in backticks exists after the change.

## 4. Within the author's permission

From the edit table in `AGENTS.md`. If an agent's change edits any of these,
the verdict is `needs_owner`, however good the edit is:

- an existing file in `decisions/` (other than appending to `open-questions.md`);
- `AGENTS.md`, or the README's goal and principles;
- an existing skill in `skills/` (a new skill is fine);
- an old `journal/` entry.

## 5. Safe for the lab

- A change to `iac/` that can alter what `tofu plan` shows (resources,
  providers, variables, backend settings) comes with that plan pasted in the
  pull request, from the one checkout that applies. Comments, docs and
  formatting in `iac/` need no plan.
- A write to infrastructure that could lose data names the snapshot or
  verified backup taken first. A service that keeps no data needs only a
  copy of its configuration; that copy needs no restore test.
- Nothing deletes or merges an XCP-ng snapshot by hand (`systems/xcp-ng.md`).
- Compose files hold secrets and identifying values (domains, public IPs,
  tailnet IPs and names) as references, never as values. Any other value
  written into the file is fine (`apps/README.md`).
- Access for agents follows `decisions/agent-access.md`: convenience first,
  with two hard guards (backups out of an agent's reach, no manual snapshot
  deletion). Asking for lockdown beyond that is not a finding.

## 6. Shaped so it can be reverted

- One commit, one change. Two unrelated changes in one commit is a finding.
- Subjects are plain prose, present tense, no prefix.

## Blockers and warnings

Report everything you find, strictly. Then sort each finding:

- **Blocker** — the change should not merge as is. Only blockers under
  sections 1 and 5 fail the CI check; the others are listed for the owner,
  who approves every pull request:
  - anything under section 1 (should not be public);
  - anything under section 5 (unsafe for the lab);
  - a fact that is invented, or a false claim about the live lab that
    would mislead whoever acts on it — saying something is deployed, backed
    up, restored or secure when it is not (section 2). Not a missing source,
    not a change labelled as not deployed or proposed yet, and not wording
    that disagrees with itself inside the change (a tense, a stale line, a
    "now" that should be "will"): those are warnings.
- **Needs owner** — section 4: the change is fine to review but the owner has
  to decide on it. Reported as the `needs_owner` verdict, listed as a blocker;
  it does not fail the check, because the owner's approval is required anyway.
- **Warning** — reported, does not block: everything else, including missing
  sources on harmless claims, wording that disagrees with itself, duplicated facts, links and paths, template
  shape (section 3), and commit shape (section 6) — history cannot change
  after a push, so commit shape is advice for the next change.

## Output

```
verdict: approve | request_changes | needs_owner
blockers:
- [section number] path:line — what is wrong — what would fix it
warnings:
- [section number] path:line — what is wrong — what would fix it
```

Write `- none` under an empty heading. `approve` means no blockers; warnings
may still be listed. `request_changes` only when there is at least one
blocker. Style opinions that break none of the rules above are not findings
at all.
