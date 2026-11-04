# The Prime reviewer: an agent that reviews and fixes the owner's pull requests

**Status:** built 2026-11-02; running through the shared action with B2
storage since pull request 30 merged. The first run of that setup was pull
request 31 on 2026-11-03: approve, run `41576294219-1` (job log read through
the GitHub API). The same reviewer was run by hand on pull requests 21, 25,
27 and 28 first; see "How it was tested". It runs the required `ai review` check
(`decisions/pull-request-gate.md`), replacing the earlier reviewer that sent
the diff to a model in one call.

## What it does

[Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent) (an open
source coding agent) reads the pull request against `repo/review.md` and
`AGENTS.md`, then sorts each finding by level:

| Level | Kind | What happens |
|---|---|---|
| 1 | mechanical: a broken path, a status value outside the vocabulary, a stale index line | it commits the fix to the pull request's branch itself; the workflow pushes it only if the commit avoids protected paths and the properties check still passes |
| 2 | a clear change of a few lines | a suggestion on the line, applied with **Commit suggestion**; lines outside the diff cannot carry one, so those go in the summary |
| 3 | design | a comment with no code; reply `/prime <instruction>` (for example "do it") and it continues the same session and commits |

It reports only findings that meet the bar in `repo/review.md`
("Blockers and warnings"), not wording or style. Never on its own: `iac/`, `decisions/`, `.github/`,
`.githooks/`, `skills/`, `journal/`, `AGENTS.md`, `README.md`, `CLAUDE.md`,
`repo/review.md` — anything there is level 3. Source: `protected` in the
private `repos/homelab/config.toml`, read 2026-11-03.

## When it runs

`.github/workflows/prime-review.yml`. The job's first step stops every pull
request and comment that is not the owner's: the job holds a model key and a
token that can push.

| Event | What it does | Comments |
|---|---|---|
| the owner opens a pull request | full review, job named `ai review`; a line in the pull request body starting with `/prime ` adds a focus | always |
| the owner pushes to it | continues the same session and re-reviews the new commits; `ai review` passes or fails on the result | only when it has something new |
| the reviewer's own fix commits arrive | reuses the verdict of the run that pushed them, no model call | never |
| the owner comments `/prime` or `/prime review [focus]` | a new full review, job named `prime` (not a check) | always |
| the owner comments `/prime <anything else>`, in the conversation or on a line | follows the instruction in the same session, for example "do it" on a level 3 | a reply |
| a pull request someone else opened | `ai review` fails with "not reviewed"; the owner reviews it by hand | none |

`ai review` fails on a blocker under `repo/review.md` sections 1 or 5, or
when the reviewer produced no result. A 👀 reaction on a `/prime` comment
means it started, 🚀 that it finished, 😕 that it failed.

## Watching a run

The run's log shows one line per step: the tool call (the command it ran or
the files it read), and after each model turn the tokens so far and the cost
so far. Its reasoning and prompts never appear there, because the logs of a
public repository are readable by anyone. The run's summary page has a table:
mode, verdict, findings, fixes, duration, turns, tokens, cost and the trace's
folder.

## Where it runs and where its state lives

On GitHub's hosted runners: a fresh virtual machine per run, discarded after,
free for a public repository. Nothing runs on the lab.

| What | Where |
|---|---|
| The rules it judges by | `repo/review.md` and `AGENTS.md`, always from `main`, so a pull request cannot rewrite them |
| Shared execution code | public `prime-reviewer-action`, called as a composite action at commit `aca0791870e6` (pinned by full SHA) by this repo's workflow |
| Its prompts, playbook and model settings | the owner's private repo `prime-reviewer` (`main`): shared `APPEND_SYSTEM.md` and `skills/common-review/`, with homelab settings and playbook in `repos/homelab/` |
| Changes it makes to its own playbook | a pull request on `prime-reviewer`, which the owner merges or closes |
| Each pull request's session (so `/prime <instruction>` continues it) | B2: `sessions/<owner>/<repo>/<pr>/latest.json` references its saved session archive; the private Git `state` branch keeps the sessions from before the cutover as rollback |
| Each run's trace: every message, tool call, token count and cost | B2: `traces/<owner>/<repo>/<pr>/<run-id>.tar.gz` contains manifest, metadata, result, root transcript and child transcripts; the private Git `state` branch retains earlier records as rollback |

The prompts and traces are private because workflow artifacts and logs of a
public repository are readable by anyone; the run log shows only the outcome.
Prime's usage telemetry is off (`DO_NOT_TRACK=1`).

A trace viewer (Phoenix, Langfuse or OpenObserve) is not chosen yet
(`decisions/open-questions.md`, AI reviewer). The B2 trace archives, plus
the `state` branch's folders from before the cutover, are the input for it:
each review comment ends with the run ID that names its trace.

## Setup (done 2026-11-02)

- A GitHub App owned by the owner, installed on this repo and
  `prime-reviewer` only, with read and write access to contents, pull
  requests and issues, and no webhook. The workflow turns its key into a
  token that lasts an hour. Its pushes start this repo's other checks, which
  pushes made with the workflow's own token would not.
- Repository settings: variable `PRIME_APP_ID`; secrets
  `PRIME_APP_PRIVATE_KEY` and `OPENCODE_API_KEY` (the model provider, OpenCode
  Go). Both secrets are also kept in OpenBao (`systems/openbao.md`). Five
  more `PRIME_B2_*` secrets hold the B2 storage fields (see below).
- Selected model: `muse-spark-1.3-contributor` through OpenCode Go (owner,
  2026-11-03; local Prime smoke test returned `ok`, exit 0), set in the
  private `repos/homelab/config.toml`; pull request 31's run used it.
  Prime Agent version is pinned by the shared action's `prime-version` input.

## How it was tested

By hand on 2026-11-02, before the workflow existed, with the same prompts on
a laptop: it found the main mistake a later pull request had to fix in pull
request 21, and on pull request 27 it went from 18 findings in 17 minutes
(no playbook) to 9 in 6 minutes (with it). It missed version numbers that
the `ai review` check flags, which led to the playbook's mandatory section 1
step; whether that step works is not yet tested.

## Shared action and repository folders

Prepared at the owner's request, 2026-11-03: `.github/workflows/prime-review.yml`
now calls the public composite action, retaining the `ai review` job name and
owner-only triggers. Its former local script moved to that action. Source:
workflow and action diff, Python regression tests, and parsed private TOML.
The private core and common lessons are shared; each repository has its own
`repos/<repo>/config.toml` and `playbook/SKILL.md`, on one branch. The action's
README owns its inputs and onboarding steps.

Old homelab sessions are restored on demand and saved under the namespaced
path on their next run. Trace selection checks the full repository name, so
another repository's PR with the same number cannot reuse its verdict.
A `config-ref` input can select an experimental prompt branch; lesson PRs
then target that branch. No other repository has been enrolled by this change.
The composite action's first live run was pull request 31 (see Status).

## B2 migration and future trace viewers

The owner approved private Backblaze B2 storage on 2026-11-03 after comparing
it with the Git state branch. It went live when pull request 30 merged; the
first run on B2 was pull request 31. The Git state branch is kept intact as
the rollback source. The first import used snapshot
`3297851510fa93871fbbb8256d581ca2cd4a2de5` (two PR sessions, two trace
bundles). The final refresh before cutover used `adab215d33c3861e0affe6e723d7f09a1d410019`,
the branch's head when it was read on 2026-11-03 (two sessions, four trace
bundles; private `state` branch listing).

The replacement caller explicitly requests B2 and fails when its credentials
are missing, rather than silently saving a new conversation elsewhere. New
storage restores this PR's session only, writes a complete immutable run
archive, and updates its latest pointer after the upload succeeds. The Git
backend stays in the action for callers that give no B2 inputs. No old state
is deleted by this change, and no retention period is assumed.

Runtime credentials live in OpenBao at `kv/general/prime-reviewer-b2`,
with the required fields configured as this repository's Actions secrets.
The supplied endpoint was normalized to HTTPS and its region derived from
its host name. Read-only B2 authorization and ACL checks confirmed a private
bucket and a runtime key restricted to that one bucket (2026-11-03).
The bucket is separate from the lab's backup store. From the pin below,
Prime runs as its own Linux user on copies of the pull request, rules and
config, and receives only its model key and review inputs (the action
README's "Isolation"). First live run: the owner's `/prime` comment on pull
request 27, run `41781483852-1` on 2026-11-04 (job log read through the
GitHub API): the user was created, Prime ran on the copies, its state saved
to B2 and its reply was posted. That run also showed that a conversation
saved before the move did not continue; the pin below is meant to fix that,
**UNTESTED** live until a `/prime` reply on a pull request whose session was
saved before the move continues it.

The action's `observability.md` owns the future importer boundary: raw root
and child transcripts, versioned metadata, model/config provenance and run
boundaries can be replayed later into a chosen viewer. Phoenix, Langfuse and
OpenObserve expose OpenTelemetry ingestion, but require their own attribute
and authentication adapters (official ingestion documentation checked
2026-11-03; links in that file). No viewer or live exporter is deployed yet.

Migration verification, 2026-11-03: `migrate_state.py` imported the two PR
sessions and two trace bundles from the source snapshot above, downloaded
them, and compared session files and root/child transcript contents. All
comparisons passed. The original Git state remains intact. Details and the
cutover limitation are recorded in
`journal/2026-11-03-prime-reviewer-b2-migration.md`.

Release verification, 2026-11-04: the caller pins action commit
`aca0791870e6564064d8b3a9dfd2f110f87c1067`, `main` of `prime-reviewer-action` after pull requests 1 to 5. Over
`v1.1.0` (`1ead3e3f070aebbc2963609834f6147df66e589b`) it adds: Prime running
as its own user, both sides of a moved file checked against protected paths,
boto3 installed where the wrapper imports it, and saved conversations
continued after the move to Prime's working folder. Prime's `-c` continues
only a session whose header records the current folder (Prime 0.10.2,
`print_runtime.rs`), so the wrapper points the newest saved session there.
The action's offline suite (37 tests) passes at that commit, and a local run
as a separate user, with a stand-in that continues sessions the way Prime
does (not Prime itself), continued a session saved under the old folder. A full
SHA is pinned because a tag can be moved; the commit is not tagged yet. The
pull request that sets the pin is still reviewed on the previous pin,
because the gate takes this workflow from `main`; the first run on this pin
is the next pull request or `/prime` comment after it merges.
