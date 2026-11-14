---
type: plan
status: "replaced by plans/home-overhaul.md"
verified: "no (current step unrecorded; restore tests open in systems/backups.md)"
hosts:
  - XCP-ng host
  - TrueNAS VM
tags:
  - plan
  - migration
  - portainer-to-git
---

# Migration

The current migration, in order. Each step gates the next.

**Status:** replaced by `plans/home-overhaul.md` on 2026-11-14 (owner). Kept as
history; do not work from this page.
**Goal** (proposed, owner to confirm): move every workload onto the new setup
without losing data, with each one's definition in this repo.
**Done when** (proposed, owner to confirm): every workload runs on the new
setup, its definition is in this repo, and the re-hardening pass (step 3) has a
journal entry.

0. **Backups verified + re-audit.** Confirm snapshots exist and pass the
   restore rule in `systems/backups.md`. Re-audit the current setup first.
1. **Inventory + read-only security baseline, in parallel.** List what exists
   (done in `inventory/`) and probe what is exposed, without changing
   anything.
2. **Migrate.** Move workloads to the new setup. Apps' databases move to the
   shared server where that fits (`plans/shared-postgres.md`).
3. **Re-harden.** Audit again after boot — the migrated setup gets its own
   security pass, not the old one's assumptions.
4. **Docs from day 1.** Notes start as raw dumps during the work and get
   compiled here after. This repo is that compiled result.

> [!IMPORTANT] Gate
> No step-2 writes until step-0 snapshots are verified.

## What step 2 waits on (owner, 2026-11-01)

Each service's shape when it moves — where its database lives, how it signs
in, how it is exposed — comes from three things decided first:

1. **SSO** on the VPS (`plans/vps-foundations.md`, step 4). Not blocked by the
   edge decision: only forward-auth for apps with no sign-in of their own
   waits on it.
2. **Pigsty** (`plans/shared-postgres.md`), so each app's database moves once.
3. **The edge** (`ideas/edge-and-security-layers.md`), on hold until the
   Pangolin decision. It only changes how a service is *exposed*: keep
   routing (labels or proxy entries) out of the Compose file, so internal-only
   stacks can move before the edge is chosen and public ones get their route
   last.

Also needed: the homelab running again (down since 2026-10-31 per Hindsight;
current state not checked) and a little cleanup before the home Pigsty node
(owner).

Security tool: Strix (security scanner). Always framed as defensive work on
my own network: "audit my own infra at <range>, read-only recon first,
report, then harden." Bare "scan for vulnerabilities" phrasing gets refused
by some models regardless of scope.

## Homeserver stacks: Portainer -> git (planned, not started)

Today every homeserver stack exists only inside Portainer: its Compose file and
`.env` live in Portainer's database, not here. The target:

- One directory per app in git: `compose.yaml`, with secrets and identifying
  values as references (`${VAR}` and `file:` secrets) and everything else
  written in (`apps/README.md`).
- A container manager that deploys from that directory, so the repo — not the
  UI — is the source of truth. Which manager is open
  (`decisions/open-questions.md`).
- One stack at a time; the old copy keeps running until the new one is healthy.
- Some stacks are three years old and may be retired instead of migrated.
