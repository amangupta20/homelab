# Migration

The current migration, in order. Each step gates the next.

0. **Backups verified + re-audit.** Confirm snapshots exist and pass the
   restore rule in `backup-restore.md`. Re-audit the current setup first.
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
