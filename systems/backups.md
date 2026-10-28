---
type: system
status: "jobs reported running, restores untested"
verified: "no (jobs in docs, no restore test on record; VPS read from Dokploy recon 2026-10-26)"
hosts:
  - "[XCP-ng host](../inventory/hosts.md)"
  - "[TrueNAS VM](../inventory/hosts.md)"
  - "[Remote VPS](../inventory/hosts.md)"
related:
  - "[XCP-ng](xcp-ng.md)"
  - "[OpenBao](openbao.md)"
  - "[VPS](vps.md)"
  - "[Services](../inventory/services.md)"
tags:
  - system
  - backups
  - recovery
---

# Backup & restore

What gets backed up, and — more importantly — what restore is still untested.
This file owns the backup facts; other pages link here.

**Status:** jobs reported running; no restore test on record, and the
OpenTofu state has no backup at all (see "Still to test").

- Plain VMs: Xen Orchestra (XO) snapshot + delta backups (only changed
  blocks) go to TrueNAS, then get copied offsite. No per-VM backup agent:
  image backups cover them.
- XO's own config + pool metadata: daily at midnight (`0 0 * * *`), 10 copies
  kept, success/failure posted to the `xen-orchestra` ntfy topic.
- Apps with internal state (Nextcloud): VM image plus an app-level Borg
  backup from inside the app, managed through BorgWarehouse on TrueNAS.
- OpenTofu state: a `tofu state pull` export offsite is planned but **not
  implemented**, so the state bucket is a single copy today.
- Remote VPS: Dokploy backs up its own database and the volumes or
  databases of 12 service names to one destination, `garage` — the Garage
  store at home, addressed by its home LAN IP, presumably through a Tailscale
  subnet route (not checked). Two projects both name their service `app`, so
  the exact number of apps is unclear. Most runs succeed; every run of the
  backup of the `odysseus` service (project `Odyssues`) has failed (88 of 88
  in Dokploy's list). Read from
  Dokploy's backup list, recon 2026-10-26.

All of the above except the remote VPS line is what the docs say is
configured; nobody has compared it to the live XO schedules yet. The VPS line
was read from Dokploy.

## The rule

> [!IMPORTANT]
> A backup counts when a test restore works. A green job log alone counts for
> nothing, and neither does Uptime Kuma saying a service is "up".

## Still to test

- [ ] TrueNAS: wipe-and-reimport from backup (clean-import test)
- [ ] Nextcloud: full recovery from Borg backup
- [ ] XO config + pool metadata: no restore on record
- [ ] Pre-migration re-audit (before the migration in `plans/migration.md`)
- [ ] OpenTofu state: scheduled `tofu state pull` export offsite — not built yet
- [ ] VPS: restore one Dokploy app backup and Dokploy's own database backup from Garage
