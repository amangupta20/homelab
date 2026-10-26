# AGENTS.md — how to work in this repo

You are an AI agent (or a future-me who forgot context). This file tells you
how to work here without breaking things.

Read in this order:
1. `README.md` — what this homelab is, and the "Find something" map
2. `decisions/open-questions.md` — what is undecided or unverified; do not
   treat anything listed there as fact
3. `decisions/docs-layout.md` — which file owns which kind of fact, and who
   may edit what
4. `inventory/` — services, hosts, IPs
5. `systems/xcp-ng.md` — the platform rule that destroys VMs
6. The README of the folder you are about to write in — it has the naming
   rules and the template
7. The `systems/` page, `plans/` file or `runbooks/` entry for your task

## What you may edit

| Files | You may |
|---|---|
| `inventory/`, `systems/`, `plans/`, `apps/`, `iac/README.md`, `repo/` | edit, as long as every fact you add says how you know it |
| `journal/` | add a new entry at the end of every task; never edit an old one except to append a follow-up |
| `runbooks/` | follow; propose changes only |
| `decisions/open-questions.md` | append; never delete or resolve an item |
| `decisions/` (everything else), `AGENTS.md`, `README.md` goal and principles | propose only, in a separate commit for the owner to review |

The owner keeps the design; you keep the facts current.

## When facts disagree

If two files disagree, or a file disagrees with what you observe on the live
lab, or a file contradicts `decisions/open-questions.md`: do not pick a side.
Add the contradiction to `decisions/open-questions.md` — what each source says
and how you saw it — and stop that part of the task. Whichever source you read
first is not automatically right.

## Rules

- Write for a stranger. Spell out acronyms on first use. Say why, not just
  what. No filler, no marketing words ("robust", "seamless"), no fake
  completeness. If something is untested, say so.
- Every fact says how it is known. A fact you add names its source: the
  command you ran, the UI page you read, or "from memory, unverified". A
  number nobody measured is labelled as a guess.
- Every command in a doc has been run at least once, or is marked
  **UNTESTED**. A plausible-looking recipe nobody ran is worse than none.
- No secrets in this repo. No tokens, passwords, private keys, real public
  domains, or full configs containing secrets. Examples use placeholders like
  `__PASTE_ONCE__`. See `systems/openbao.md` for where secrets live, and
  `repo/secret-scanning.md` for the scan that blocks a commit or push.
- Look before touching. Read-only recon first (list, describe, plan), report
  what you found, then change.
- Snapshots or verified backups before any write to infrastructure. Say which
  snapshot you took.
- Infrastructure changes go through OpenTofu: paste `tofu plan` output in the
  task before `tofu apply`. Never apply blind.
- One fact, one owner. `inventory/services.md` owns the service list,
  `inventory/network.md` owns IPs, `systems/<thing>.md` owns how each thing
  works. Update the owner file, link to it from elsewhere — don't copy the
  fact.
- One commit, one change. Keep commits atomic: a hook plus the docs and config
  it needs travel together, two unrelated changes never do. History is the
  traceback — when something breaks, the commit that caused it should be
  findable and revertable on its own. No drive-by fixes inside an unrelated
  commit, and no "and also" commits. Commit subjects are plain prose, present
  tense, saying what changed (this repo does not use a prefix convention).

## Danger rules (do not break)

- Never delete an XCP-ng base snapshot by hand. A base snapshot can be a link
  in the live disk chain — deleting it corrupts the VM. Only merge/delete
  through the Xen Orchestra web UI, with a verified backup first. In July 2026
  manual handling destroyed VMs and cost ~2 days. See
  `systems/xcp-ng.md`.
- A backup is not done when the job says success. It is done when a test
  restore works. See `systems/backups.md`.

## Task contract (Paperclip / Hermes / any agent)

- The task body must state: what to do, scope (which VM/service), read-only
  or write, and how to tell it worked (acceptance).
- Your outcome must state: what changed, `tofu plan` output if relevant, how
  you verified it, and what is still open.
- If scope is unclear, ask. Doing nothing is better than doing the wrong
  thing. Never invent busywork to look useful.
