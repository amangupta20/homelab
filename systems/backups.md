---
type: system
tags:
  - system
  - backups
  - recovery
---

# Backup & restore

What gets backed up, and — more importantly — what restore is still untested.
This file owns the backup facts; other pages link here.

**Status:** jobs reported running; OpenBao (Garage and B2 offsite), shared Postgres (B2) and the Oracle Cloud
OpenTofu state (Garage copy) restores tested, other restores untested (see "Still
to test").

- Plain VMs: Xen Orchestra (XO) snapshot + delta backups (only changed
  blocks) go to TrueNAS, then get copied offsite. No per-VM backup agent:
  image backups cover them.
- XO's own config + pool metadata: daily at midnight (`0 0 * * *`), 10 copies
  kept, success/failure posted to the `xen-orchestra` ntfy topic.
- Apps with internal state (Nextcloud): VM image plus an app-level Borg
  backup from inside the app, managed through BorgWarehouse on TrueNAS.
- OpenTofu state: both roots (`iac/` for Xen Orchestra since 2026-11-16,
  `iac/oci/` since 2026-11-05) keep their state encrypted in one Backblaze B2
  bucket, which keeps every old version. Each root's `run.sh` copies the
  encrypted object to Garage's `opentofu` bucket whenever Garage's newest copy
  differs, checked after every command, timestamped, newest 14 kept
  (`iac/lib/state-copy.sh`). Garage being down never fails a command; the next
  run catches up. The Oracle
  state's copy was restore-tested on 2026-11-16
  (`journal/2026-11-16-restore-test-tofu-state-garage.md`), and the Xen
  Orchestra state's the same evening, once it held `cache-1`
  (`journal/2026-11-16-build-cache-1.md`).
- Remote VPS: Dokploy backs up its own database and the volumes or
  databases of 12 service names to one destination, `garage` — the Garage
  store at home, addressed by its home LAN IP, presumably through a Tailscale
  subnet route (not checked). Two projects both name their service `app`, so
  the exact number of apps is unclear. Most runs succeed; every run of the
  backup of the `odysseus` service (project `Odyssues`) has failed (88 of 88
  in Dokploy's list). Read from
  Dokploy's backup list, recon 2026-10-26.
- OpenBao Raft snapshot: Dokploy Scheduled Task `openbao-raft-snapshot` (daily
  02:00 IST), streams Raft snapshot via OpenBao API (encrypted at rest by OpenBao's
  internal AES-256-GCM barrier keyring; source: OpenBao architecture / Raft storage docs),
  uploads to Tier 1 Garage destination `s3://dockploy/openbao/` (10s connection timeout fallback if offline)
  and Tier 2 Backblaze B2 offsite (`s3://<b2-bucket>/openbao/`), pruning to keep 14 backups on each destination.
  Restore tested 2026-10-29 from Garage (`journal/2026-10-29-restore-test-openbao.md`)
  and 2026-10-31 from Backblaze B2 (`journal/2026-10-31-restore-test-openbao-b2.md`).

Read live on 2026-11-14 (Xen Orchestra's REST API, the TrueNAS API, the Nextcloud backup container's log):

- Xen Orchestra has two VM backup jobs over the same six running VMs (NPM-set,
  adguard-docker, apt-cache, gpu_docker, portainer instance, xo-ce): **Rolling**,
  snapshots only, daily at 00:00, 7 kept; and **mainback**, a delta backup to one
  backup location, daily at 06:00 (where that location is was not read: the REST
  API does not list it). mainback has 363 runs since 2025-08-27: 212 succeeded,
  131 failed, 20 were interrupted; the latest runs succeeded. A third job, "XO
  config and pool data", ran 105 times, all successful. **The TrueNAS VM is in
  no job**, and neither is any stopped VM.
- Nextcloud AIO backs itself up with Borg every night at 22:00 to BorgWarehouse
  on TrueNAS, keeping everything from the last 7 days plus 4 weekly and 6 monthly
  archives; the last run, 2026-11-13, succeeded (73 GB, 59 GB stored after
  deduplication across all archives).
- TrueNAS snapshots and the `imp/back` to `Main/repli` replica: `systems/truenas.md`.
  Snapshots run daily again (2026-11-14 and -15); the replica's last good copy is
  still 2026-10-30 and is being redone after a checksum error.

All of the above except the remote VPS, OpenBao and 2026-11-14 lines is what the docs say
is configured; nobody has compared it to the live XO schedules yet. The VPS apps
line was read from Dokploy, and the OpenBao backup and restore were tested on
2026-10-29 (Garage) and 2026-10-31 (Backblaze B2).

In force: every service keeps its local tier on Garage, and the important ones
add an offsite tier on B2 (`decisions/backup-tiers.md`, how: `agents/skills/back-up-a-service/`,
plan: `plans/offsite-backups.md`). OpenBao has both tiers in place.

## The rule

> [!IMPORTANT]
> A backup counts when a test restore works. A green job log alone counts for
> nothing, and neither does Uptime Kuma saying a service is "up".

## Tested restores

- [x] OpenBao (Tier 1 Garage S3): Raft snapshot restore from Garage S3 into a fresh throwaway
  instance on the workstation (`journal/2026-10-29-restore-test-openbao.md`).
- [x] Shared Postgres (Tier 2 Backblaze B2 offsite): pgBackRest point-in-time restore into a
  scratch folder on `pigsty-1` (`journal/2026-11-06-install-pigsty.md`).
- [x] Shared Postgres, one database (Tier 2 Backblaze B2 offsite): `blinko` restored and copied into a new database, on `pigsty-1`
  and then on the workstation with only OpenBao and the repo, and compared (`journal/2026-11-07-restore-test-blinko-copy.md`).
  The app did not run on the copy.
- [x] OpenBao (Tier 2 Backblaze B2 offsite): Raft snapshot restore from Backblaze B2 into
  a fresh throwaway instance on the workstation (`journal/2026-10-31-restore-test-openbao-b2.md`).

## Still to test

- [ ] TrueNAS: wipe-and-reimport from backup (clean-import test)
- [ ] Nextcloud: full recovery from Borg backup
- [ ] XO config + pool metadata: no restore on record
- [ ] Pre-migration re-audit (before the migration in `plans/home-overhaul.md`)
- [x] OpenTofu state: Oracle Cloud state restored from its Garage copy, `tofu plan` reported no changes (2026-11-16)
- [x] OpenTofu state: Xen Orchestra state restored from its Garage copy (`xcp-ng/20261116T172306Z.tfstate`), `tofu plan` reported no changes with `cache-1` in it (2026-11-16)
- [ ] VPS: restore one Dokploy app backup and Dokploy's own database backup from Garage
