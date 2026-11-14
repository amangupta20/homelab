---
type: system
status: "running; replica and snapshots last ran 2026-10-30"
verified: "yes (TrueNAS API and Xen Orchestra's REST API, 2026-11-14)"
hosts:
  - TrueNAS VM
  - XCP-ng host
tags:
  - system
  - storage
  - truenas
  - zfs
---

# TrueNAS

The storage VM: two ZFS pools on two physical disks, the file shares the home
apps use, and two apps (Garage and BorgWarehouse).

**Status:** running. Its snapshots and its one replication task last ran on
2026-10-30, before the lab went down; they run again at their next 19:00.
Rows: `inventory/hosts.md`, `inventory/services.md`. Where it is going:
`plans/home-overhaul.md`.

## How it works

Read on 2026-11-14 through the TrueNAS API (`system/info`, `disk`, `pool`,
`pool/dataset`, `sharing/smb`, `pool/snapshottask`, `replication`, `cloudsync`,
`app`, `cronjob`) and Xen Orchestra's REST API, unless a line says otherwise.

- **Version and size:** TrueNAS 25.10.4, a VM named `aaTruenas-core` with
  4 CPUs and 8 GB RAM. Its boot disk (40 GB) is on the XCP-ng host's `Local
  storage` repository.
- **Disks:** a 2 TB and a 1 TB hard disk, each handed to the VM whole through
  XCP-ng's `Pass_Drives` storage repository (type `udev`, which maps a
  physical disk straight into a VM). ZFS owns each disk entirely, with no
  image file in between. Inside TrueNAS they appear as `xvdb` and `xvdc` with
  no model or serial number, so TrueNAS cannot read their SMART health: that
  has to be read on the XCP-ng host. The scheduled SMART test cron job in
  TrueNAS therefore checks nothing real.
- **Pools:** one disk each, no redundancy inside a pool.

  | Pool | Disk | Size | Used | Datasets (used) |
  |---|---|---|---|---|
  | `imp` | 1 TB | 0.91 TiB | 0.43 TiB | `back` 431 GiB (18 GiB of it snapshots), `norm` 16 GiB, `ioapp` 9 GiB |
  | `Main` | 2 TB | 1.81 TiB | 1.38 TiB | `home` 650 GiB, `repli` 413 GiB, `S3_Garage` 345 GiB, `borgwarehouse` 55 GiB, `iocage` (empty, left from TrueNAS CORE), `Tnas-Config` |

  Compression saves little (ratios 1.0–1.1×), as expected for photos and video.
  Both pools were healthy and their last scrub finished.
- **What is in the shares** (top-level folders seen from the GPU VM over SMB,
  2026-11-14): `back` holds `immich`, `nextcloud`, `paperless`, `Books`,
  two personal folders, `BACKUPDISK`, `imp` and `cert`; `home` holds `media`,
  `download`, `imp`, `aa` and `lala`; `norm` holds `crafty`, `minio`,
  `OS_ISO` and `VM_BACK`.
- **Shares:** SMB shares `back` (`imp/back`), `norm` (`imp/norm`) and `home`
  (`Main/home`). NFS is running with no shares.
- **Snapshots:** daily at 19:00 — `imp/back` (recursive, kept 2 weeks),
  `Main/home` (recursive, kept 1 week), `imp/ioapp` (at 00:00, kept 2 weeks).
- **Replication:** `imp/back` to `Main/repli`, after each snapshot; last run
  2026-10-30 (`imp/back@auto-2026-10-30_19-00`).
- **Cloud sync:** only `config-back`, the TrueNAS configuration, which last
  succeeded 2026-11-13. The Google Drive tasks were deleted by the owner on
  2026-11-14, to be set up again properly (`plans/home-overhaul.md`).
- **Apps:** Garage 1.2.5 and BorgWarehouse 1.1.10, both with an update
  available. A cron job copies the apps' own folder (`/mnt/.ix-apps/`) into
  `imp/ioapp` with `rsync --delete`.

## Rules

- **Never delete a snapshot on the XCP-ng side by hand** (`systems/xcp-ng.md`).
  TrueNAS's own ZFS snapshots are separate and safe to manage in TrueNAS.
- **Read disk health on the XCP-ng host**, not in TrueNAS: the passed-through
  disks hide their SMART data from the VM.

## Backups

`systems/backups.md`. TrueNAS itself is not in Xen Orchestra's backup jobs;
its data is protected by its snapshots, the replica in `Main/repli`, and
Nextcloud's own Borg backups.

## Open questions

`decisions/open-questions.md`, "Backups".
