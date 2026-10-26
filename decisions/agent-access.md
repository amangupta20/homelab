# Agents get convenient access; disaster recovery is the safety net

Decided: 2026-10-26. Status: in force.

## Why

The owner would rather accept the risk of an agent breaking something than
lose convenience to tight lockdown. The lab already has several backups, more
are planned, and with the lab documented properly a rebuild is a procedure, not
the two days lost in July 2026. An agent deleting the system is unlikely;
recovering from it is planned for.

So agents get the access a task needs to be done smoothly. Read-only first and
approval before writes stay as working habits (`AGENTS.md`), but nothing
should be locked down so hard that routine work becomes painful.

## What still holds without exception

Two guards cost no convenience and keep recovery possible:

- **An agent's credentials cannot delete or overwrite backups.** Backups live
  on a boundary the agent cannot write to. In a widely reported April 2026
  incident an agent found an API token in a file, deleted a production volume,
  and the backups on that same volume went with it.
- **No agent deletes or merges an XCP-ng base snapshot by hand**
  (`systems/xcp-ng.md`).

## Cost / what this rules out

- No read-only proxies, command allowlists or approval gateways in front of
  every tool by default. They can be added for a specific risky tool when one
  turns out to need it.
- Recovery has to be real: the restore tests in `systems/backups.md` matter
  more under this decision, not less.
- Reviewers (`repo/review.md`) should not ask for extra lockdown beyond the
  two guards above.

## Where it lives

`AGENTS.md`, `systems/backups.md`, `systems/xcp-ng.md`.
