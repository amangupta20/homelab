---
type: idea
status: "idea"
verified: "no (design only; nothing built or run)"
tags:
  - idea
  - updates
  - ansible
---

# Updates checked by an LLM before they install

**Status:** idea
**In one line:** every 3 days a script lists a machine's available updates and asks an LLM
whether they are entirely safe. If so they install; at the slightest risk they wait for the
owner, who decides. Every run is logged.
**Why try it:** updates stay current, including Tailscale's port on `pigsty-1`, without the
owner reading every changelog, and without blind auto-updates on machines that matter.
**Needs first:** nothing hard. The escalation path should be working, and home being up
would give a second machine to try it on.

## Design sketch

The owner's flow (2026-11-06), with the rest proposed by an agent:

1. **Collect**, every 3 days: `apt-get -s dist-upgrade`, and each package's changelog.
2. **Fixed rules first**, with no LLM. Some packages always escalate: the kernel, anything
   needing a reboot, Tailscale (the only admin path), Docker, Postgres, Patroni and etcd.
3. **Ask the LLM**, for packages that pass. It has internet access and does the surface
   checks nobody has time to do by hand for every update: security advisories, the project's
   issue tracker, other people's reports of breakage or compromise, and how long the release
   has been out. It answers in a fixed format, `safe` or `escalate`, with reasons and sources.
4. **Safe:** install, then run a health check, and alert if it fails.
5. **Anything else escalates:** a run with no valid answer, a timeout, or the LLM being down.
   The owner gets a notice and decides.
6. **Log every run:** what was offered, what was asked, the answer, what happened.

To decide: where it runs. A timer on each machine, installed by Ansible, is simplest: it
needs only an LLM key and a way to notify. A central runner would need SSH access to every
machine, which makes it a high-value target and needs its own tailnet rule.

## Risks and costs

- **It will not catch everything.** A careful compromise has a clean changelog and no reports
  yet, so `safe` means nothing visible looks wrong. The owner could not catch that either, and
  auditing by hand is not realistic (owner, 2026-11-06), so the bar is doing better than no
  check. Waiting a few days after a release gives other people time to report problems for it
  to find.
- **Changelogs and web pages are untrusted input.** Text in either could try to talk the LLM
  into answering `safe`. Fixed rules run first for that reason, its only power is that one
  word, and the machine running it should hold no other credentials.
- **False confidence.** Being told "safe" feels stronger than it is, so the fixed rules must
  stay the real guard for machines that matter.
- **The log stays out of this repo.** Versions of public-facing software must not be
  published (`AGENTS.md`), so it goes somewhere private. A `journal/` entry for each
  automatic run would be too noisy; to decide how the journal rule applies.
- **Ubuntu already auto-updates.** See "Sources". Installing through this gate means deciding
  what to do with `unattended-upgrades`, or it bypasses the check.
- **Each failure mode costs attention:** if most runs escalate, it becomes noise that gets
  ignored.

## Promote when

The owner wants to build it. Other candidates to compare first: `unattended-upgrades` alone
with Tailscale's own auto-update, which is far less work.

## Sources

- Read on `pigsty-1` on 2026-11-06: `unattended-upgrades` is enabled and active, runs daily,
  allows Ubuntu's main and security origins, does not reboot by itself, and does not cover
  Tailscale's own package repository.
- From memory (Hindsight), unverified: Hermes's earlier auto-updater was paused on
  2026-10-13 after an upstream problem, and Paperclip already has a flow where an owner
  marks an issue done to approve a proposal. Either may suit the escalation step.
