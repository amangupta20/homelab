# AGENTS.md — how to work in this repo

You are an AI agent (or a future-me who forgot context). This file tells you
how to work here without breaking things.

Read in this order:
1. `README.md` — what this homelab is
2. `inventory/services.md` — what runs here, and what is broken
3. `inventory/network.md` — IPs and traffic flow
4. `platforms/xcp-ng-xen-orchestra.md` — VM platform rules, including the one
   that destroys VMs
5. The task file under `ops/` or `iac/` for whatever you were asked to do

## Rules

- Write for a stranger. Spell out acronyms on first use. Say why, not just
  what. No filler, no marketing words ("robust", "seamless"), no fake
  completeness. If something is untested, say so.
- No secrets in this repo. No tokens, passwords, private keys, real public
  domains, or full configs containing secrets. Examples use placeholders like
  `__PASTE_ONCE__`. See `docs/secrets-openbao.md` for where secrets live, and
  `docs/secret-scanning.md` for the scan that blocks a commit or push.
- Look before touching. Read-only recon first (list, describe, plan), report
  what you found, then change.
- Snapshots or verified backups before any write to infrastructure. Say which
  snapshot you took.
- Infrastructure changes go through OpenTofu: paste `tofu plan` output in the
  task before `tofu apply`. Never apply blind.
- One fact, one owner. `inventory/services.md` owns the service list,
  `inventory/network.md` owns IPs, `platforms/` owns platform rules. Update
  the owner file, link to it from elsewhere — don't copy the fact.
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
  `platforms/xcp-ng-xen-orchestra.md`.
- A backup is not done when the job says success. It is done when a test
  restore works. See `ops/backup-restore.md`.

## Task contract (Paperclip / Hermes / any agent)

- The task body must state: what to do, scope (which VM/service), read-only
  or write, and how to tell it worked (acceptance).
- Your outcome must state: what changed, `tofu plan` output if relevant, how
  you verified it, and what is still open.
- If scope is unclear, ask. Doing nothing is better than doing the wrong
  thing. Never invent busywork to look useful.
