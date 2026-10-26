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
- anything in `runbooks/`;
- an old `journal/` entry.

## 5. Safe for the lab

- A change to `iac/` comes with a `tofu plan` pasted in the pull request,
  from the one checkout that applies.
- A write to infrastructure names the snapshot or verified backup taken first.
- Nothing deletes or merges an XCP-ng snapshot by hand (`systems/xcp-ng.md`).
- Compose files hold references (`${VAR}`, secret files), never values.

## 6. Shaped so it can be reverted

- One commit, one change. Two unrelated changes in one commit is a finding.
- Subjects are plain prose, present tense, no prefix.

## Output

```
verdict: approve | request_changes | needs_owner
findings:
- [section number] path:line — what is wrong — what would fix it
```

`approve` only with no findings. Style opinions that break none of the rules
above are not findings.
