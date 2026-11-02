---
type: plan
status: "not started"
verified: "no (Prime Agent's README and source read 2026-11-02; nothing installed or run)"
tags:
  - plan
  - ai-review
  - agents
  - prime-agent
  - spot-vm
---

# AI reviewer on Prime Agent, started on demand

**Status:** not started. Chosen 2026-11-02 by the owner over PR-Agent,
dsh-superagent and Harness² for this job; dsh-superagent and Harness² are kept
for the migration agent (`ideas/dsh-superagent-and-harness2.md`).

**Goal:** Prime Agent reviews the owner's pull requests on this repo against
`repo/review.md`, on a spot VM started only for that review, answers the
owner's replies in the pull request, and gets better from run to run, with
every run's reasoning kept where the owner can read it.

**Done when:** on three consecutive owner pull requests, a spot VM started by
the trigger posts a review whose findings carry a level (below), a "go ahead"
reply on one level 3 finding produces a commit on that pull request with the
repo's checks passing, every VM is gone afterwards, and each run's trace can be
found by the ID in its comment.

This reviewer only advises. The required check stays `ai review`
(`.github/workflows/review.yml`, `decisions/pull-request-gate.md`).

## What Prime Agent is, and why it

[Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent) (Prime
Intellect, MIT license, Rust, about 22.5k GitHub stars on 2026-11-02) is a
coding agent whose one tool is a persistent Python environment; it reads and
edits files, runs commands and starts sub-agents (`rlm.spawn(...)`) from code.
Its "Continual Harness" `/refine` step reviews a finished run and saves small,
evidence-backed lessons (extra prompts, memories, skill notes), never touching
the base prompt, with snapshots for rollback. Source: its README, read
2026-11-02.

Why it for this job (owner, 2026-11-02): it sits between the two other
candidates. It runs a review well on its own like dsh-superagent, and it
improves itself from run to run like Harness², without needing either one's
extra machinery.

Its README warns that it "executes model-generated Python and project commands
with your user permissions" and "is **not** a security sandbox". Every step
below runs it under its own user, on a machine that holds nothing else.

### Command-line flags this plan relies on

Read from `crates/pa-cli/src/args.rs` on 2026-11-02. What each flag does was
inferred from its name and the surrounding code; none has been run.

| Flag | Use here |
|---|---|
| `-p` / `--print`, `--mode json` | one review per run, no interactive interface, machine-readable output |
| `--provider`, `--model`, `--api-key` | model per run; an OpenAI-compatible provider (`openai_completions`) exists |
| `--append-system-prompt`, `--skill`, `--prompt-template` | load the reviewer's instructions at run time |
| `--session-dir`, `--resume`, `--continue` | keep sessions in a folder that can be saved and restored, so a reply can resume the review |
| `--autonomous`, `--autonomous-max-turns`, `--autonomous-max-tokens`, `--autonomous-timeout-ms` | a turn, token and time budget per review |
| `--autonomous-gate` (with `-retries`, `-timeout-ms`) | commands that must pass before it may finish, such as `mise run check:properties` after it applies a fix |

### Telemetry and traces

From `crates/pa-telemetry/README.md` and `crates/pa-cli/src/client_traces.rs`,
read 2026-11-02:

- Prime sends usage analytics (event counts, no prompt or session content,
  per its README) to Prime Intellect, which forwards them to PostHog. It is
  turned off with `DO_NOT_TRACK=1` or `PRIME_AGENT_TELEMETRY=0`; the reviewer
  runs with it off.
- `/traces` uploads session trace files to Prime Intellect. The reviewer never
  uses it: the traces hold the private instructions.
- It keeps trace files locally. It has no OpenTelemetry export, so it cannot
  send traces to Phoenix or Langfuse by itself.

## How a review works

Three levels of finding, one rule each:

| Level | Kind | What the reviewer does |
|---|---|---|
| 1 | mechanical: a typo, a broken path or link, formatting, a property block that disagrees with its page | pushes a fix commit itself and says so, only for an allowed list of fix kinds, and only if the repo's checks pass afterwards |
| 2 | a clear change of a few lines | posts a GitHub suggestion block; the owner applies it with **Commit suggestion** |
| 3 | design: "X was done; Y or case Z was not considered" | a comment with no code; a "go ahead" reply resumes the session, which implements it as one commit and answers in the thread |

Limits on every level:

- Nothing it changes by itself touches `iac/` resources, `decisions/`,
  `AGENTS.md` or another folder's rules; those are level 3 only.
- Its own commits never start another review.
- A cap on rounds per pull request.
- Everything it writes is public: it names a path, a line and the kind of
  value for anything that should not be public, never the value
  (`repo/review.md` section 1, `AGENTS.md` security rule).

## Memory: three kinds, three places

| Kind | Example | Where |
|---|---|---|
| what it knows | past decisions, the owner's preferences | Hindsight, read through its MCP server; Prime supports MCP servers (README) |
| what it is doing | the open review a "go ahead" resumes | the session folder (`--session-dir`), saved to object storage after each run and restored before the next |
| how it works | the reviewer prompt, skills, tool manifest, `/refine` lessons | the private config repo (step 2) |

## Observability

Every run's trace files and session folder go to a bucket on Garage or B2
before the VM stops, whichever tool reads them later. The pull request comment
carries only a trace ID, never a link, because traces hold whole diffs and the
private instructions. A one-line summary (pull request, duration, cost, result,
trace ID) goes to ntfy.

Which tool shows the traces, Phoenix or Langfuse, is undecided
(`decisions/open-questions.md`, AI reviewer).

### Model calls: direct or through a proxy

Both are open until step 1 answers its questions:

| | Direct to the model API, then import Prime's trace files | Through a proxy (LiteLLM, or 9router, which already runs on the VPS) |
|---|---|---|
| In the request path | nothing extra | one more service the VM has to reach; if it is down, reviews fail |
| Records | Prime's own view, which probably includes tool calls, commands and sub-agents (file format not checked) | model calls only: each prompt and reply |
| Other agents later | one importer per agent | any agent, unchanged |
| API key | the provider key is on the spot VM | the provider key stays on the proxy; the VM gets a key that can be revoked or capped |
| OpenCode Go's session header | Prime must send `x-opencode-session` itself (unknown whether it can) | the proxy adds it once for every agent |

The working assumption: direct on the laptop. On spot VMs, import the trace
files from the bucket. Add a proxy when the provider key should leave the VMs
or when a second agent joins; check whether 9router can forward headers and
export its log before adding LiteLLM. None of it is checked.

## Steps

1. **Laptop test on two pull requests.** Prime Agent installed under a
   separate Linux user that holds only its own model key and a GitHub login
   for a private scratch copy of this repo, telemetry off. Two past pull
   requests replayed in the scratch copy. Run once interactively, then the way
   a spot VM would (`-p --mode json` with the budgets and gates). Record the
   answers here:
   - Does the OpenAI-compatible provider reach OpenCode Go, and can Prime send
     the `x-opencode-session` header?
   - What do the local trace files hold, and are they enough to see how it
     reached each finding?
   - Where does `/refine` save its lessons, and can they be kept per project
     rather than per session (its README says "local to the session by
     default")?
   - Does `--resume` work on a session folder copied to a new machine?
   - Do the gates stop it from finishing when a check fails?
   - What did each review cost?

   — gate: every question above has an answer in this plan, and the owner
   decides direct or proxy.
2. **Private config repo.** The reviewer prompt, skills, tool manifest
   (`mise.toml`, an apt package list, a `Dockerfile`) and `/refine` lessons
   live in a private repo, cloned at run time. The rules everyone follows stay
   public in `repo/review.md` and `AGENTS.md`. — gate: the owner decides the
   public and private split (`decisions/open-questions.md`, AI reviewer).
3. **Container image.** CI builds the image from the manifest whenever it
   changes and pushes it to a private registry. Every tool in it is pinned (a
   version in mise, a digest for images). A tool the reviewer finds it needs is
   added to the manifest in the private repo, never kept on a machine. — gate:
   the image runs the step 1 review on the laptop with the same result.
4. **Trigger.** A GitHub Actions workflow on pull request and comment events,
   only for the owner's pull requests and the owner's comments, with one run at
   a time, starts a preemptible Oracle VM with the event's details. Its cloud
   key may only create and terminate instances in one compartment. A scheduled
   job terminates any reviewer VM older than about 30 minutes. — gate: a test
   event starts a VM that terminates itself, and a non-owner comment starts
   nothing.
5. **Spot VM run.** cloud-init only: get a short-lived token from OpenBao,
   pull the image, clone the private repo, restore the session folder, run the
   review, save the session folder and trace files to the bucket, post the
   result, shut down. — gate: a review on the scratch copy completes, and a
   second run resumes it from a "go ahead" reply.
6. **Trace viewer.** Phoenix or Langfuse, once the open question is decided,
   loaded from the bucket. — gate: a run's trace is found by the ID in its
   comment.
7. **This repo.** Point the trigger at this repo, levels 2 and 3 only at
   first; level 1 auto-fixes once the owner trusts the findings. — gate: the
   Done when line above.

## Links

- Candidates kept for the migration agent: `ideas/dsh-superagent-and-harness2.md`
- On-demand starting of the trace viewer: `ideas/on-demand-container-wakeups.md`
- The required review check: `repo/review.md`, `decisions/pull-request-gate.md`
- Backups for the bucket and the viewer: `skills/back-up-a-service/`
- Undecided parts: `decisions/open-questions.md`, AI reviewer
