---
type: system
status: "jobs reported running; OpenBao restore tested (Garage and B2 offsite), others untested"
verified: "partially (OpenBao restore tested 2026-10-29 from Garage and 2026-10-31 from B2; others from docs/memory; VPS read from Dokploy recon 2026-10-26)"
hosts:
  - XCP-ng host
  - TrueNAS VM
  - Remote VPS
tags:
  - system
  - backups
  - recovery
---

# Backup & restore

What gets backed up, and — more importantly — what restore is still untested.
This file owns the backup facts; other pages link here.

**Status:** jobs reported running; OpenBao restore tested 2026-10-29 (Garage) and 2026-10-31 (Backblaze B2 offsite), other
restores untested, and the OpenTofu state has no backup at all (see "Still to
test").

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
- OpenBao Raft snapshot: Dokploy Scheduled Task `openbao-raft-snapshot` (daily
  02:00 IST), streams Raft snapshot via OpenBao API, uploads to Tier 1 Garage
  destination `s3://dockploy/openbao/` (10s connection timeout fallback if offline)
  and Tier 2 Backblaze B2 offsite (`s3://<b2-bucket>/openbao/`), pruning to keep 14
  backups on each destination.
  Restore tested 2026-10-29 from Garage (`journal/2026-10-29-restore-test-openbao.md`)
  and 2026-10-31 from Backblaze B2 (`journal/2026-10-31-restore-test-openbao-b2.md`).

All of the above except the remote VPS and OpenBao lines is what the docs say
is configured; nobody has compared it to the live XO schedules yet. The VPS apps
line was read from Dokploy, and the OpenBao backup and restore were tested on
2026-10-29 (Garage) and 2026-10-31 (Backblaze B2).

In force: every service keeps its local tier on Garage, and the important ones
add an offsite tier on B2 (`decisions/backup-tiers.md`, how: `skills/back-up-a-service/`,
plan: `plans/offsite-backups.md`). OpenBao has both tiers in place.

## The rule

> [!IMPORTANT]
> A backup counts when a test restore works. A green job log alone counts for
> nothing, and neither does Uptime Kuma saying a service is "up".

## Tested restores

- [x] OpenBao (Tier 1 Garage S3): Raft snapshot restore from Garage S3 into a fresh throwaway
  instance on the workstation (`journal/2026-10-29-restore-test-openbao.md`).
- [x] OpenBao (Tier 2 Backblaze B2 offsite): Raft snapshot restore from Backblaze B2 into
  a fresh throwaway instance on the workstation (`journal/2026-10-31-restore-test-openbao-b2.md`).

## Still to test

- [ ] TrueNAS: wipe-and-reimport from backup (clean-import test)
- [ ] Nextcloud: full recovery from Borg backup
- [ ] XO config + pool metadata: no restore on record
- [ ] Pre-migration re-audit (before the migration in `plans/migration.md`)
- [ ] OpenTofu state: scheduled `tofu state pull` export offsite — not built yet
- [ ] VPS: restore one Dokploy app backup and Dokploy's own database backup from Garage
