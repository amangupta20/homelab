# AGENTS.md — how to work in this repo

You are an AI agent (or a future-me who forgot context). **Read
`agents/rules.md` before you change anything:** how to work, what every fact
needs, how to open a pull request. Agent material lives under `agents/`; the
lab is `README.md`, `inventory/`, `systems/`, `apps/`, `iac/` and `ansible/`.

## Danger rules (do not break)

- Never delete an XCP-ng base snapshot by hand. A base snapshot can be a link
  in the live disk chain — deleting it corrupts the VM. Only merge/delete
  through the Xen Orchestra web UI, with a verified backup first (July 2026:
  manual handling destroyed VMs and cost ~2 days). See `systems/xcp-ng.md`.
- A backup is not done when the job says success. It is done when a test
  restore works. See `systems/backups.md`.
- No secrets, and no unfixed security weakness, in this public repo: not in a
  commit, its message, a pull request or a CI log. Fix a weakness with the
  owner first (`agents/rules.md`, "Rules").
- Snapshots or verified backups before any write to infrastructure, and read
  `tofu plan` before `tofu apply`.
- Every new home VM downloads through the LAN cache from its first build:
  inventory group `lan_cache_clients` and `ansible/cache-client.yml` before
  anything else is installed (`ansible/README.md`, "Adding a host"). A commit
  that adds a VM without it fails the pre-commit hook and CI.

## What you may edit

| Files | You may |
|---|---|
| `inventory/`, `systems/`, `agents/plans/`, `apps/`, `iac/README.md`, `agents/review/` | edit, as long as every fact you add says how you know it |
| `agents/ideas/` | correct facts and add sources; never promote, drop or act on an idea without the owner (`agents/ideas/README.md`) |
| `agents/journal/` | add an entry when a task changed the live lab, handled an incident, or tested a restore (`agents/journal/README.md`); never edit an old one except to append a follow-up |
| `agents/skills/` | follow; add new skills and propose changes to existing ones (`agents/skills/write-a-skill/`) |
| `agents/decisions/open-questions.md` | append; never delete or resolve an item |
| `agents/decisions/` (everything else), `agents/rules/`, `agents/rules.md`, `AGENTS.md`, `README.md` goal and principles | propose only, in a separate commit for the owner to review |

The owner keeps the design; you keep the facts current. When two sources
disagree, do not pick a side: `agents/rules.md`, "When facts disagree".
