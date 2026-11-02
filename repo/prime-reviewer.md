# The Prime reviewer: an agent that reviews and fixes the owner's pull requests

**Status:** built 2026-11-02, **UNTESTED** on GitHub until its first run
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
| Its prompts, playbook and model settings | the owner's private repo `prime-reviewer` (`main` branch): a fixed core only the owner edits, and a playbook it may improve |
| Changes it makes to its own playbook | a pull request on `prime-reviewer`, which the owner merges or closes |
| Each pull request's session (so `/prime <instruction>` continues it) | `prime-reviewer`, `state` branch, `sessions/pr-<n>/` |
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
- Model: `deepseek-v4.1-flash` through OpenCode Go; Prime Agent version
  pinned in the workflow (`PRIME_AGENT_VERSION`).

## How it was tested

By hand on 2026-11-02, before the workflow existed, with the same prompts on
a laptop: it found the main mistake a later pull request had to fix in pull
request 21, and on pull request 27 it went from 18 findings in 17 minutes
(no playbook) to 9 in 6 minutes (with it). It missed version numbers that
the `ai review` check flags, which led to the playbook's mandatory section 1
step; whether that step works is not yet tested.
