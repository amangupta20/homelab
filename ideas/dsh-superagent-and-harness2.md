---
type: idea
status: "researched"
verified: "no (research only, from both projects' READMEs and docs read 2026-11-02; nothing installed or run)"
tags:
  - idea
  - agents
  - dsh-superagent
  - harness2
  - migration
---

# A repo agent that improves itself: dsh-superagent with Harness²

**Status:** researched — not scheduled. The owner's choice for the migration
agent on the home server's dedicated agent VM, once home is back up (owner,
2026-11-02). The AI reviewer starts on Prime Agent instead
(`plans/ai-reviewer-prime-agent.md`).
**In one line:** an agent that takes work from one GitHub repo only when the
owner asks, tracks each job as a ticket with its own session and checkout, and
has its prompts, skills and guardrails tuned automatically from how past jobs
went.
**Why try it:** a working step towards an agent that is the master of one repo.
dsh-superagent supplies the intake, permissions and a panel showing every job;
Harness² supplies the improvement that dsh-superagent leaves to the operator;
Hindsight supplies what it knows about the repo and the owner.
**Needs first:** the home server back up and the agent VM in place; the AI
reviewer plan run long enough to have scored runs to compare against.

Everything below is from the projects' READMEs and docs, read 2026-11-02.
None of it has been run here.

## The pieces

### dsh-superagent: intake, permissions, tickets, panel

[dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype)
(DeepSeek, MIT, TypeScript; created 2026-10-31, about 11k GitHub stars on
2026-11-02) is a plugin for DeepSeek Harness (`@deepseek-ai/dsh`, pinned at
`0.2.1-rc.3` in its deployment doc). Its README calls it a "research prototype
for reference only, not an official DeepSeek product", with "much of the
engineering done by coding agents".

- **Principle** (`docs/000-philosophy.md`): "Take as little human attention as
  possible, and give as much value as possible." It confirms a request once,
  stays quiet while working, and writes again only with a result, a question
  or a failure. It "stops by impact, not by effort": a local change goes as far
  as a reviewable result, a design decision stops with a question.
- **Who can ask** (`docs/002-authorization.md`): allowed lists and an admission
  table per source, enforced by the host; messages cannot change permissions.
  Bots can never make explicit requests. Work nobody asked for needs a written
  rule and starts in a mode that only records what it would have done.
- **Execution** (`docs/003-execution.md`): each request becomes a ticket with
  its own agent session (`worker-<ticket id>`) and directory, usually a
  `git worktree` made by a setup command. A reply on the same thread continues
  that ticket. It never enables auto-merge as itself.
- **Panel** (`docs/005-panel.md`): traces each job from the incoming message,
  through the decision with its reason and matched rules, to the ticket; the
  Prompts tab shows the assembled prompt with version history and a diff
  against the defaults.
- **Deployment** (`docs/006-deployment.md`): it needs its own GitHub user
  account (not a GitHub App, because it reads that account's notifications),
  polls GitHub rather than receiving webhooks, and serves the panel on
  `127.0.0.1`. Workers run without approval, with full access, as the
  operator's OS user; the doc says the wrappers "establish defaults, not a
  security boundary".
- **Models:** any provider DeepSeek Harness supports (owner, 2026-11-02; the
  deployment doc says "a model provider configured for DeepSeek Harness").

### Harness²: improving the setup from past jobs

[Harness²](https://github.com/google-research/harness2) (Google Research,
Apache-2.0, Python; about 22k GitHub stars on 2026-11-02; paper arXiv
2610.14224) tunes eight parts around a fixed model: system prompt, guardrails,
memory, tool guidance, sub-agents, skills, scripts and plugins.

- **On one task:** propose edits to the setup, rerun the same task with each
  (probe), and combine the edits whose runs behaved better (compose). It needs
  no answer key: the contrast between runs is the signal.
- **Across tasks:** it keeps the adopted setup and lessons the evidence
  supports, to guide the next round.
- **Agents it runs:** OpenCode (default) or Codex. Its documented improver and
  judge models are on Google's Vertex AI (`docs/SETUP.md`).
- Its README: one round improved GLM-5 and Gemini 3.5 Flash on its three
  benchmarks, by up to 11.8 points. Not reproduced here.

### Hindsight: what it knows

dsh-superagent has no long-term memory, and Harness²'s memory is about
improving the setup. Repo knowledge comes from Hindsight's `repo:homelab`
memories, which a worker would search.

## Design sketch

- **dsh-superagent** runs on the agent VM under its own OS user, with an agent
  GitHub account allowed only on the repos it works on, and the owner as the
  only allowed person.
- **Harness²** runs on a schedule over recent jobs. Each of its eight parts
  maps onto something dsh-superagent stores: prompt sections and built-in parts
  (versioned in the panel), skills, blocked commands and delivery rules,
  worker sub-agents, the setup command and scripts. Memory has no
  dsh-superagent equivalent.
- **The adapter** to build: Harness² running a dsh-superagent worker on a past
  job with a candidate setup. Harness² ships with OpenCode and Codex only; how
  much work a dsh-superagent adapter is was not checked.
- **What it may change by itself:** its own prompts and skills in the private
  config repo, each as a versioned change with the evidence behind it, so it
  can be rolled back. Anything in this repo's rules (`repo/review.md`,
  `AGENTS.md`, `skills/`) is a pull request for the owner. For the first weeks
  it only proposes.
- **Prime Agent** stays the yardstick: with the adapter in place, rerun its
  past reviews and compare.

## Risks and costs

- Both are new: dsh-superagent is two days old at the time of writing and
  pinned to a release-candidate harness; expect rough edges.
- No sandbox in either: every worker can run anything as its OS user, so the
  VM and the user hold nothing else, and the GitHub account reaches only the
  repos it works on.
- A self-tuning setup edits its own instructions, which pulls against "the
  owner keeps the design" (`AGENTS.md`); the proposal-only start and the
  pull-request rule for public rules are the answer proposed here.
- Model cost multiplies: each Harness² round reruns jobs once per candidate.
- dsh-superagent's own design assumes it runs continuously; on the agent VM it
  would.

## Promote when

The home server is back, the agent VM exists, and the Prime Agent reviewer
has a month of scored runs to compare a tuned dsh-superagent against.

## Sources

- dsh-superagent: README and `docs/000`, `002`, `003`, `005`, `006`, read via
  the GitHub API 2026-11-02.
- Harness²: README and `docs/SETUP.md`, read via the GitHub API 2026-11-02.
- The choice of these two for the migration agent, and of Prime Agent for the
  reviewer: the owner, in a research conversation 2026-11-02.
- Unverified: dsh-superagent's model support beyond the owner's statement, the
  adapter effort, and Harness² with a non-Vertex improver.
