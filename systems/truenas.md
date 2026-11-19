---
type: system
tags:
  - system
  - storage
  - truenas
  - zfs
---

# TrueNAS

The storage VM: two ZFS pools on two physical disks, the file shares the home
apps use, and two apps (Garage and BorgWarehouse).

**Status:** running. Snapshots run daily again (2026-11-14 and -15). The
replication failed on 2026-11-15 on a checksum error in `imp`, was redone the
same evening, and `Main/repli` now holds `auto-2026-11-15_20-00`; a scrub of
`imp` afterwards found no errors ("Checksum errors on `imp`" below).
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
- **The physical disks** (`smartctl -a` and `/dev/disk/by-id` on the XCP-ng
  host, run by the owner 2026-11-15):

  | Pool | Host device | Model | Power-on hours | SMART notes |
  |---|---|---|---|---|
  | `imp` | `sdd` | WD Blue WD10EZEX, 1 TB, 7200 rpm | 31,300 | PASSED; 0 reallocated, 0 pending, 0 uncorrectable; **4 UDMA CRC errors** (link errors, usually the cable); 3,767 start/stop cycles; last self-test at 22,728 hours |
  | `Main` | `sdc` | Toshiba P300 HDWD320, 2 TB, 7200 rpm | 18,330 | PASSED; no errors of any kind; **drive-managed SMR** (`Zoned Device: Device managed zones`), which slows long sustained writes such as a resilver or a large replication; no self-test ever run |

  The XCP-ng host's RAM is not ECC (`dmidecode -t memory` on the host:
  `Error Correction Type: None`), so ZFS cannot rule out a bit-flip in
  memory as the cause of a checksum error.
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
- **Replication:** `imp/back` to `Main/repli`, after each snapshot. The
  19:00 run on 2026-11-15 failed (see "Checksum errors on `imp`" below); the
  rerun finished at 20:04 IST with `imp/back@auto-2026-11-15_20-00` as its last
  snapshot, the newest on both sides (TrueNAS API `replication` and
  `pool/snapshot`, 2026-11-16).
- **Cloud sync:** only `config-back`, the TrueNAS configuration, which last
  succeeded 2026-11-13. The Google Drive tasks were deleted by the owner on
  2026-11-14, to be set up again properly (`plans/home-overhaul.md`).
- **Apps:** Garage 1.2.5 and BorgWarehouse 1.1.10, both with an update
  available. A cron job copies the apps' own folder (`/mnt/.ix-apps/`) into
  `imp/ioapp` with `rsync --delete`.

## Mounting the shares on a Linux laptop

**UNTESTED** recipe, given to the owner on 2026-11-14. The password goes in a root-only
file, never in `/etc/fstab`:

```bash
sudo install -d -m 700 /etc/samba/credentials
sudo install -m 600 /dev/stdin /etc/samba/credentials/nas <<'EOF2'
username=<user>
password=__PASTE_ONCE__
EOF2
sudo mkdir -p /mnt/nas/{back,norm,home}
for s in back norm home; do
  echo "//10.22.33.160/$s /mnt/nas/$s cifs credentials=/etc/samba/credentials/nas,uid=$(id -u),gid=$(id -g),vers=3.1.1,_netdev,nofail,noauto,x-systemd.automount,x-systemd.idle-timeout=10min,x-systemd.mount-timeout=15s 0 0" | sudo tee -a /etc/fstab
done
sudo systemctl daemon-reload
```

A share mounts on first access and unmounts when idle. Away from home it goes through
the router's subnet route, which Linux ignores until `sudo tailscale set
--accept-routes` has been run once. For a one-off: `gio mount smb://10.22.33.160/back`.
The share names change when the datasets are reorganised (`plans/home-overhaul.md`, B1).

## Checksum errors on `imp` (2026-11-15, closed 2026-11-16)

The 19:00 replication on 2026-11-15 stopped with `cannot send
'imp/back@auto-2026-11-15_19-00': Input/output error`, and TrueNAS raised a
critical `ReplicationFailed` alert. `zpool status -v imp` (owner, TrueNAS
shell) showed 8 checksum errors on `xvdc1`, no read or write errors, and one
damaged file: a library inside a Python virtual environment
(`back/nextcloud/admin/files/.../.venv/.../libcublasLt.so.12`), live and in
that one snapshot. Reading it back gave `Input/output error`, so the bad block
is on disk.

How it is read, not proved: the file was created at 00:59 on 2026-11-15 during
a bulk rewrite of `back/nextcloud` (93,535 files changed between 00:30 and
02:00, `find -newerct`), the owner's Nextcloud restore. The scrub that ended at
02:08 had started before the file existed, so it never checked it. The disk
surface is clean and the host logged no disk errors, so the likeliest cause is
corruption on the way to the disk (non-ECC RAM, or the link with 4 CRC
errors), not a failing disk.

What was done (owner, 2026-11-15): the damaged virtual environment was
deleted, `auto-2026-11-15_19-00` destroyed, the partial receive on
`Main/repli` discarded (`zfs receive -A`), a fresh snapshot
`auto-2026-11-15_20-00` taken and the replication started by hand.

Checked through the TrueNAS API on 2026-11-16 (`replication`, `pool/snapshot`,
`pool`): the replication finished at 20:04 IST on 2026-11-15 and `Main/repli`
holds `auto-2026-11-15_20-00`. A scrub of `imp` ran from 20:14 to 21:18 IST
that evening and finished with 0 errors; it is the first check of the other
files the restore wrote. The pool is `ONLINE` and healthy, and `xvdc1` now
shows 0 read, write and checksum errors. Still to do at the next shutdown:
reseat or replace the WD's SATA cable and run a memory test on the host, since
the cause was never found.

## Rules

- **Never delete a snapshot on the XCP-ng side by hand** (`systems/xcp-ng.md`).
  TrueNAS's own ZFS snapshots are separate and safe to manage in TrueNAS.
- **Read disk health on the XCP-ng host**, not in TrueNAS: the passed-through
  disks hide their SMART data from the VM.
- **Move scripted reads off the REST API before upgrading to 26.04.** TrueNAS
  25.10.4 warns that the REST API (`/api/v2.0/...`, which the recon used) is
  deprecated and removed in version 26.04; the replacement is its JSON-RPC 2.0
  API over a WebSocket (TrueNAS alert `RESTAPIUsage`, 2026-11-15).

## Backups

`systems/backups.md`. TrueNAS itself is not in Xen Orchestra's backup jobs;
its data is protected by its snapshots, the replica in `Main/repli`, and
Nextcloud's own Borg backups.

## Open questions

`agents/decisions/open-questions.md`, "Backups".
