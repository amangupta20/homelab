# Backup & restore

What gets backed up, and — more importantly — what restore is still untested.
This file owns the backup facts; other pages link here.

- Plain VMs: Xen Orchestra (XO) snapshot + delta backups (only changed
  blocks) go to TrueNAS, then get copied offsite. No per-VM backup agent:
  image backups cover them.
- XO's own config + pool metadata: daily at midnight (`0 0 * * *`), 10 copies
  kept, success/failure posted to the `xen-orchestra` ntfy topic.
- Apps with internal state (Nextcloud): VM image plus an app-level Borg
  backup from inside the app, managed through BorgWarehouse on TrueNAS.
- OpenTofu state: a `tofu state pull` export offsite is planned but **not
  implemented**, so the state bucket is a single copy today.

All of the above is what the docs say is configured. Nobody has compared it to
the live XO schedules yet.

## The rule

A backup counts when a test restore works. A green job log alone counts for
nothing, and neither does Uptime Kuma saying a service is "up".

## Still to test

- [ ] TrueNAS: wipe-and-reimport from backup (clean-import test)
- [ ] Nextcloud: full recovery from Borg backup
- [ ] XO config + pool metadata: no restore on record
- [ ] Pre-migration re-audit (before the migration in `plans/migration.md`)
- [ ] OpenTofu state: scheduled `tofu state pull` export offsite — not built yet
