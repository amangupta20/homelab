# The Prime reviewer: an agent that reviews and fixes the owner's pull requests

**Status:** built 2026-11-02; shared action migration prepared 2026-11-03,
**UNTESTED** on GitHub until its first run
(the same reviewer was run by hand on pull requests 21, 25, 27 and 28 first;
see "How it was tested"). It runs the required `ai review` check
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

It reports only findings that would mislead someone or break a rule, not
wording or style. Never on its own: `iac/`, `decisions/`, `.github/`,
`.githooks/`, `AGENTS.md`, `README.md` — anything there is level 3.

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
| Shared execution code | public `prime-reviewer-action`, called as a composite action at `v1` by this repo's workflow |
| Its prompts, playbook and model settings | the owner's private repo `prime-reviewer` (`main`): shared `APPEND_SYSTEM.md` and `skills/common-review/`, with homelab settings and playbook in `repos/homelab/` |
| Changes it makes to its own playbook | a pull request on `prime-reviewer`, which the owner merges or closes |
| Each pull request's session (so `/prime <instruction>` continues it) | `prime-reviewer`, `state` branch, `sessions/homelab/pr-<n>/` (reads the old path as a fallback) |
| Each run's trace: every message, tool call, token count and cost | `prime-reviewer`, `state` branch, `traces/<run-id>/` (`meta.json`, `result.json`, `session.jsonl`, and `subagents/` for any sub-agent it started); written even when a later step of the run fails |

The prompts and traces are private because workflow artifacts and logs of a
public repository are readable by anyone; the run log shows only the outcome.
Prime's usage telemetry is off (`DO_NOT_TRACK=1`).

A trace viewer (Phoenix, Langfuse or OpenObserve) is not chosen yet
(`decisions/open-questions.md`, AI reviewer). The `state` branch's trace
folders are the input for it: each review comment ends with the run ID that
names its folder.

## Setup (done 2026-11-02)

- A GitHub App owned by the owner, installed on this repo and
  `prime-reviewer` only, with read and write access to contents, pull
  requests and issues, and no webhook. The workflow turns its key into a
  token that lasts an hour. Its pushes start this repo's other checks, which
  pushes made with the workflow's own token would not.
- Repository settings: variable `PRIME_APP_ID`; secrets
  `PRIME_APP_PRIVATE_KEY` and `OPENCODE_API_KEY` (the model provider, OpenCode
  Go). Both secrets are also kept in OpenBao (`systems/openbao.md`).
- Selected model: `muse-spark-1.3-contributor` through OpenCode Go (owner,
  2026-11-03; local Prime smoke test returned `ok`, exit 0). The private
  `repos/homelab/config.toml` is updated. The old default-branch caller
  still hardcodes DeepSeek until this replacement workflow merges.
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
Live validation of the composite action remains **UNTESTED** until this
workflow merges to the default branch.

## B2 migration and future trace viewers

The owner approved private Backblaze B2 storage on 2026-11-03 after comparing
it with the Git state branch. This migration is **prepared, not activated**:
B2 access and upload/download restore tests passed; switching the live
caller still waits for the workflow merge. The
current Git state remains intact and is the rollback source. Read-only source
snapshot `3297851510fa93871fbbb8256d581ca2cd4a2de5` contained two PR sessions
and two trace bundles (private `state` branch clone and metadata count,
2026-11-03). Recheck the source after the last legacy run before cutover;
that count and snapshot are observations, not a permanent inventory.

The replacement caller explicitly requests B2 and fails when its credentials
are missing, rather than silently saving a new conversation elsewhere. New
storage restores this PR's session only, writes a complete immutable run
archive, and updates its latest pointer after the upload succeeds. The old
Git backend remains available to earlier callers during rollout. No old state
is deleted by this change, and no retention period is assumed.

Runtime credentials live in OpenBao at `kv/general/prime-reviewer-b2`,
with the required fields configured as this repository's Actions secrets.
The supplied endpoint was normalized to HTTPS and its region derived from
its host name. Read-only B2 authorization and ACL checks confirmed a private
bucket and a runtime key restricted to that one bucket (2026-11-03).
The bucket is separate from the lab's backup store. The model subprocess
receives its model key and review inputs; B2 credentials stay in the wrapper.

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
