# Migration

The current migration, in order. Each step gates the next.

**Status:** in progress — the current step is not recorded. Step 0's restore
tests are all still open in `systems/backups.md`.
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
2. **Migrate.** Move workloads to the new setup.
3. **Re-harden.** Audit again after boot — the migrated setup gets its own
   security pass, not the old one's assumptions.
4. **Docs from day 1.** Notes start as raw dumps during the work and get
   compiled here after. This repo is that compiled result.

Gate: no step-2 writes until step-0 snapshots are verified.

Security tool: Strix (security scanner). Always framed as defensive work on
my own network: "audit my own infra at <range>, read-only recon first,
report, then harden." Bare "scan for vulnerabilities" phrasing gets refused
by some models regardless of scope.

## Homeserver stacks: Portainer -> git (planned, not started)

Today every homeserver stack exists only inside Portainer: its Compose file and
`.env` live in Portainer's database, not here. The target:

- One directory per app in git: `compose.yaml` plus references (`${VAR}` and
  `file:` secrets), never values.
- A container manager that deploys from that directory, so the repo — not the
  UI — is the source of truth. Which manager is open
  (`decisions/open-questions.md`).
- One stack at a time; the old copy keeps running until the new one is healthy.
- Some stacks are three years old and may be retired instead of migrated.
