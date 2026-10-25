# Backup & restore

What gets backed up, and — more importantly — what restore is still untested.

- Plain VMs: Xen Orchestra snapshot + delta backups go to TrueNAS, then get
  copied offsite. No per-VM backup agent needed.
- XO's own config + pool metadata: daily at midnight, 10 copies kept,
  success/failure posted to ntfy.
- Apps with internal state (Nextcloud): VM image plus an app-level Borg
  backup from inside the app.

## The rule

A backup counts when a test restore works. A green job log alone counts for
nothing.

## Still to test

- [ ] TrueNAS: wipe-and-reimport from backup (clean-import test)
- [ ] Nextcloud: full recovery from Borg backup
- [ ] Pre-migration re-audit (before the migration in `migration.md`)
