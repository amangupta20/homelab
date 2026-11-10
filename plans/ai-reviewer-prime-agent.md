---
type: plan
status: "in progress (step 7)"
verified: "partly (run by hand on pull requests 21, 25, 27, 28 on 2026-11-02; first GitHub run on pull request 29)"
tags:
  - plan
  - ai-review
  - agents
  - prime-agent
  - spot-vm
---

# AI reviewer on Prime Agent, started on demand

**Status:** in progress (step 7). Built on 2026-11-02 as a GitHub App run on
GitHub's hosted runners instead of spot VMs (steps 2 to 6 below were replaced
by that design; how it works now: `repo/prime-reviewer.md`). Chosen 2026-11-02 by the owner over PR-Agent,
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

It now runs the required `ai review` check itself, replacing the earlier
single-call reviewer (owner, 2026-11-02; `repo/prime-reviewer.md`).

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

Which tool shows the traces: Langfuse, chosen by the owner on 2026-11-10
(step 6). The entry in `decisions/open-questions.md`, AI reviewer, stays
until the owner closes it.

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
6. **Trace viewer and evaluation.** Next after the SSO from
   `plans/vps-foundations.md`, step 4, is up — Authentik, chosen by the owner
   on 2026-11-10, recorded in PR #61. The owner put it there on 2026-11-10,
   because the run log shows one line per step and the owner cannot see what
   the reviewer read, called or said.
   - **Langfuse**, by the owner's choice of 2026-11-10, over Phoenix and Opik:
     it also scores and evaluates runs, which the owner wants to learn, and
     the VPS has the room. Its MIT edition has tracing, scores, datasets and
     model-run evaluation; a license key adds team and admin features, of
     which only data retention matters here (old traces are then deleted
     through its API instead). Its own login takes an OIDC provider; Opik's
     self-hosted edition has no login at all. Sources, read 2026-11-10:
     Langfuse's `LICENSE` (copyright now ClickHouse, Inc.) and its
     "Enterprise License Key" self-hosting page; Opik's FAQ.
   - Langfuse v4's Compose file has web, worker, an AI gateway, ClickHouse,
     MinIO, Redis and Postgres (read 2026-11-10). The stack is
     `apps/vps/langfuse/` (owner's choices, 2026-11-10): Postgres on the shared
     cluster (`plans/shared-postgres.md`), a private B2 bucket instead of
     MinIO, no AI gateway, a public domain with sign-in through Authentik
     only, and asleep when idle behind Sablier (`plans/sablier-wakeups.md`)
     from the start, back to always on if that causes trouble. A cold start
     took 14 s on the workstation; on the VPS untested.
   - Deployed on the VPS on 2026-11-10 (`journal/2026-11-10-deploy-langfuse.md`);
     a wake took 27–35 s there. ClickHouse, which holds
     the hand-made scores, has no backup yet (`apps/vps/langfuse/README.md`).
     The importer (`apps/vps/langfuse/importer/`, 2026-11-10) reads the
     finished run archives from B2 with the reviewer's own key (owner's choice
     over a read-only one, 2026-11-10) and sends them as
     OpenTelemetry spans; its boundary is the action's `observability.md`. The
     76 runs in B2 were imported with matching token and cost totals; 37 were
     resumed, none failed yet. The ClickHouse backup waits for Garage (owner,
     2026-11-10: ClickHouse's own `BACKUP` to S3, in a couple of days).
     Following a run live comes after the importer works.
   - Evaluation grows from the reviewer's own runs, no prepared data set: (1)
     read traces; (2) mark runs and findings by hand (useful, noise, missed
     something); (3) a model scores each new run against a question such as
     "does each finding cite a rule"; (4) the pull requests where the reviewer
     missed something become a data set, re-run before a playbook change.
     Each stage is useful without the next.
   - Also seen 2026-11-10: a `/prime` reply on a line comment answers only in
     that thread, so nothing in the pull request's conversation shows it ran.
   — gate: a run's trace, with its messages, tool calls and files read, is
   found by the ID in its comment; one successful, one failed and one resumed
   run imported with matching token totals (`observability.md`); one run
   scored by hand.
7. **This repo.** Point the trigger at this repo, levels 2 and 3 only at
   first; level 1 auto-fixes once the owner trusts the findings. — gate: the
   Done when line above.

## Links

- Candidates kept for the migration agent: `ideas/dsh-superagent-and-harness2.md`
- On-demand starting of the trace viewer: `ideas/on-demand-container-wakeups.md`
- The required review check: `repo/review.md`, `decisions/pull-request-gate.md`
- Backups for the bucket and the viewer: `skills/back-up-a-service/`
- Undecided parts: `decisions/open-questions.md`, AI reviewer


## Next iteration: complete default review experience

**Status:** in progress; owner approved implementation 2026-11-03. Runtime
activation and live verification remain pending. Source: owner discussion.
The target is a CodeRabbit-like default experience: opening a PR produces a
useful review without choosing commands; pushes and replies continue that
review. This is a product target, not a claim of feature parity.

The review sequence is owned by `repo/review.md`, "Default review sequence":
intent, correctness, security, usability, verification and continuity. Apply
it proportionately and refine against real PRs; preserve experimentation,
useful optional features and the existing concise reporting bar.

Explicit event/command routing and CI awareness are approved directions;
implementation remains pending. Keep automatic review, incremental update,
question, requested fix and rerun paths distinct while preserving natural
language replies. Test bot-loop prevention, queued events, stale commit
results and retries. Present progress, failure and retry instructions clearly.

Reference inspected 2026-11-03: PR-Agent's reviewer prompt at
https://github.com/The-PR-Agent/pr-agent/blob/main/pr_agent/settings/pr_reviewer_prompts.toml
uses concrete triggers, confidence, security checks and structured findings.
Its optional fields are not all enabled defaults. CodeRabbit's public app
listing describes automatic incremental reviews, summaries, walkthroughs,
inline suggestions and chat: https://github.com/apps/coderabbitai.
These inform the proposal; neither product's internal quality is assumed.

### Observability and cleanup: deferred

The owner explicitly accepts accumulating B2 objects until the observability
stack is deployed (2026-11-03). Do not implement or enable PR-aware cleanup
now. Research and refine this proposed strategy during that deployment:

- Keep a PR's sessions and traces while it is open.
- After closure or merge, delete them only once every run has been imported
  into the chosen viewer and verified there. A successful send alone is not
  verification; missing or failed imports retain the source and are retried.
- A run no longer referenced by `latest.json` is only an older resume point,
  not evidence that its trace was imported or can be deleted.
- Define destination-specific import receipts, archive identity/checksums,
  duplicate handling, partial cleanup recovery and closure/reopen races before
  enabling deletion. Decide whether a final resumable session must survive:
  viewer history alone does not guarantee Prime can resume a reopened PR.

The future importer/exporter is the bridge from saved Prime records to the
chosen viewer's trace format. It is not currently deployed. The public
action repository's `observability.md` owns its technical integration boundary.
