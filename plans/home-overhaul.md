---
type: plan
status: "in progress (A1 done, A2 next)"
verified: "partially (A1 verified 2026-11-14; storage figures from the owner's TrueNAS screenshots 2026-11-14, not yet read by an agent)"
hosts:
  - XCP-ng host
  - TrueNAS VM
tags:
  - plan
  - migration
  - storage
  - portainer-to-git
---

# Home overhaul

**Status:** in progress — A1 done 2026-11-14 (`systems/oob.md`); A2, the read-only
check of TrueNAS and the GPU VM, is next. Replaces `plans/migration.md`
(owner, 2026-11-14).

**Goal:** move every home workload to a setup where each app's data has one known
place and one known backup method, app definitions live in this repo and deploy
through Arcane, and public apps are reached through Pangolin — so later changes are
one app at a time, not another overhaul.

**Done when:** every home app runs from `apps/homeserver/<app>/` on `docker-1` or `gpu-1`
with a tested restore of its data; public apps go through Pangolin; the old GPU VM,
the SMB-mount setup, the 500-second start delay and Portainer are gone; and the
re-hardening pass (step 3 of the old plan) has a journal entry.

Decisions on this page are the owner's, made in conversation on 2026-11-14, unless a
line says otherwise. Anything marked **UNTESTED** has not been run here.

## Where things stand (2026-11-14)

From the owner's TrueNAS screenshots (Datasets and Data Protection pages), not yet
read by an agent:

| Pool | Disk | Used / free | Datasets |
|---|---|---|---|
| `imp` | 1 TB | 461 / 455 GiB | `back` 431 GiB (important: Nextcloud data, Immich library, personal files, more; SMB), `norm` 16 GiB (unimportant leftovers; SMB), `ioapp` 9 GiB (TrueNAS apps) |
| `Main` | 2 TB | 1.61 TiB / 200 GiB (about 89% full) | `home` 793 GiB (normal data; SMB), `repli` 413 GiB (copy of `imp/back`), `S3_Garage` 385 GiB, `borgwarehouse` 55 GiB, `iocage` (empty, left from TrueNAS CORE), `Tnas-Config` |

- Periodic snapshots of `Main` and `imp/back` last ran 15 days before the screenshot,
  and nothing warned anyone.
- The three Google Drive cloud sync tasks mostly failed. The owner is deleting them
  until offsite copies are set up properly (2026-11-14); the files already in Drive
  stay.
- The GPU VM mounts three SMB shares and bind-mounts folders from them into
  containers; Docker starts after a fixed 500-second delay so the shares are up
  (owner).
- `Main` past about 80% full slows ZFS down and leaves the copies no room to grow.

## Design

### Where an app's data lives

The rule is by app (owner, 2026-11-14):

| App | Its data | Backup |
|---|---|---|
| **Large-data apps** — Immich, Nextcloud, Jellyfin | the big data (library, user files, media) in a **ZFS dataset** on TrueNAS over NFS; their small config in a local Docker volume | the dataset: ZFS snapshots plus the app's own backup tool or a ZFS copy on the other disk; the config: as below |
| **Other stateful apps without Postgres** | everything in **local Docker volumes** on the VM, the way Dokploy runs apps | a per-app volume backup to Garage (tier 1); B2 for the important ones |
| **Apps with Postgres** | the database in the shared cluster (below); anything else in local volumes | pgBackRest for the database; volumes as above |

SQLite and other databases never go over NFS: SQLite's locking breaks on it.
Postgres goes to the shared cluster (below).

Which tool does the per-app volume backups is checked in B3: Arcane, if it can;
otherwise a backup container per stack such as `offen/docker-volume-backup`
(stops the app, uploads to Garage over S3, prunes; **UNTESTED**, from memory).

Checks for particular apps, done when each one moves:

- **Nextcloud All-in-One is an exception.** Its master container creates and manages
  the rest itself, including its own Postgres and its Borg backups, so Arcane deploys
  only the master container. Its data folder is a host path (`NEXTCLOUD_DATADIR`), so
  the Nextcloud dataset is mounted over NFS on the VM itself, not as a Docker volume.
  A plain Nextcloud stack on the shared Postgres is the alternative; it gives up
  AIO's backups.
- **Immich's database needs a vector-search extension** (VectorChord). Before Immich
  moves to the shared cluster, check that Pigsty ships the version Immich needs;
  otherwise Immich keeps its bundled Postgres in a local volume.
- **Database and files restored to the same moment.** For an app split between
  Postgres and a dataset, its restore test restores both to matching times. Immich
  makes this easy: its database dump lands inside the library folder.

### Datasets

Grouped by how much they matter, so one recursive snapshot task and one
replication task per group cover every dataset in it, and a new app's dataset is
protected the moment it is created:

```
imp (1 TB) — live data
  imp/data/<name>     large important data: nextcloud, immich, ...   critical
  imp/files/<topic>   personal files, today's `back` split by content critical
  imp/scratch         today's `norm`                                 no backup
Main (2 TB) — copies, backup targets, normal data
  Main/repl           ZFS copies of critical datasets that have no backup tool of their own
  Main/borg           BorgWarehouse: Nextcloud's own Borg backups
  Main/garage         Garage: VPS backups, volume backups, pgBackRest
  Main/media          media for Jellyfin: replaceable
  Main/home           normal data
```

Rules:

- **One backup method per dataset, never two.** If the app's own tool covers its
  files and its database (Nextcloud All-in-One's Borg), that tool writes to
  `Main/borg` and the dataset is not also copied by ZFS. Otherwise a ZFS copy goes to
  `Main/repl`. Immich's own backup only dumps its database (into the library
  folder), so the Immich library gets a ZFS copy.
- **Live data on one disk, its copy on the other.** No single disk failure takes
  out data and its copy together.
- **Offsite:** important data goes to Backblaze B2, encrypted, later in the overhaul
  (`decisions/backup-tiers.md`). `Main/home` goes back to Google Drive, split into
  several smaller sync tasks so each one finishes (Drive caps uploads at about
  750 GB a day — from memory, unverified).
- **Access from the owner's machines:** containers use NFS. Whether the owner can
  write to an app's data over SMB or NFS is decided per app when it moves; the
  default is read-only, because editing behind Nextcloud or Immich breaks them.
  Media for Jellyfin is writable, so the owner can add files. Mixing SMB and NFS on
  one dataset needs matching permissions in TrueNAS; tried first in the pilot.
- **NFS exports** are limited to the VMs and machines that need them; `hard` mounts,
  NFS 4.2 (**UNTESTED** here).

### Machines

- **`docker-1`** (new) for most apps, and **`gpu-1`** (new) for apps that need the
  GPU (Jellyfin transcoding, AI). Both are built from this repo: OpenTofu for the VM,
  cloud-init for the first key, Ansible for the rest. Their local volumes are backed
  up per app; until each of those restores has been tested, `docker-1` also keeps a
  low-frequency Xen Orchestra delta backup. VM backups end once every app on a VM has
  a tested data restore.
- **GPU cutover:** a passed-through GPU can be attached to one running VM only. Once
  the non-GPU apps have moved, shut down the old GPU VM, attach the GPU to `gpu-1`,
  start it. Rollback is the reverse. The old VM stays powered off until the owner is
  satisfied, then is deleted.
- **Start-up waits for the NAS instead of sleeping:** a systemd service that checks
  TrueNAS's NFS port until it answers (with a cap, about 15 minutes) runs before
  Docker; `hard` NFS mounts make running apps pause, not die, when TrueNAS reboots;
  a timer runs `docker compose up -d` (or Arcane's equivalent) every few minutes to
  start anything that failed to start; XCP-ng starts TrueNAS first. Apps on local
  volumes start without waiting. **UNTESTED**; as far as known, Docker does not
  retry a container whose NFS volume failed to mount at boot, which is why the timer
  exists.
- **Container manager:** Arcane (owner, 2026-11-14). B3 checks it can deploy from git,
  give containers secrets from OpenBao and back up volumes; if it cannot read OpenBao,
  a sidecar writing `/run/secrets` does (`decisions/open-questions.md`, "Container
  runtime").
- **Accepted risk:** TrueNAS and the Docker VMs share one physical host, so a
  hardware failure stops everything at home at once.
- **TrueNAS does storage only:** Garage and the backup jobs stay on it; every other
  TrueNAS app moves to `docker-1`. Garage's metadata stays on local disk, never NFS.

### Public access

Home is behind carrier-grade NAT, so nothing can be forwarded in; that is why the
edge moves from Nginx Proxy Manager to Pangolin (owner, 2026-11-14). The Pangolin
server runs on a new VM in `pigsty-1`'s Oracle Cloud account, using the capacity
`iac/oci/pigsty.tf` keeps for it: 1 Ampere CPU, 6 GB RAM, 50 GB disk. Newt runs at
home. Design and open choices: `ideas/edge-and-security-layers.md`.

The VM should get a reserved public IP, so the Cloudflare records never change; an
ephemeral IP cannot be turned into a reserved one with the same address later.
Oracle does not document the free tier's reserved-IP limit; users report one.
Check the account's Service Limits page before creating the VM.

### Databases

Home apps' Postgres databases go to the shared Pigsty cluster
(`plans/shared-postgres.md`), with a node at home. Only the primary takes writes.
Where the primary sits is open (owner, 2026-11-14): the owner leans to the VPS as
primary and home as the failover, and wants to see first what an outage does.
Expected, **UNTESTED**:

- **Primary on the VPS:** if home loses internet for 2 minutes, home apps cannot
  write for 2 minutes; apps whose database clients reconnect carry on, apps that
  crash are restarted by Docker. The home replica falls behind and catches up.
- **Primary at home:** home loses contact with the cluster's tiebreakers, so Patroni
  demotes it (about 30 seconds by default, from memory) and the VPS takes over: two
  role changes for a 2-minute blip.

The owner prefers the VPS as primary and home as the failover (2026-11-14): home
outages then only touch home apps, and the VPS side can be upgraded with home as the
fallback. Two limits, from the cluster layout in `plans/shared-postgres.md`:

- **Planned VPS work starts with a switchover.** Before upgrading `pigsty-1`, move
  the primary home with `patronictl switchover`, which waits for the replica to catch
  up and loses nothing; move it back afterwards. An unplanned failover with
  asynchronous replication can lose the last seconds of writes.
- **Home cannot take over if both Oracle machines are down.** The etcd votes are
  `pigsty-1`, the home node and a tiebreaker on the Dokploy VPS. Losing one Oracle
  machine leaves two of three and home can become primary; losing both — an Oracle
  region or account problem, or working on both at once — leaves home alone with no
  primary anywhere. Never work on `pigsty-1` and the Dokploy VPS at the same time.

D1 tests this before any app with a database moves.

## Steps

Each step gates the next. Internal apps can move before the public edge exists;
only public apps wait for C, and only apps with a Postgres database wait for D.

### A. Before anything at home changes

1. **A second way in.** Done 2026-11-14: `oob-1` (`systems/oob.md`).
2. **Read-only check of TrueNAS and the GPU VM.** TrueNAS: version, whether the
   disks are passed through to the VM (owner thinks so; verify), pools, datasets
   and what `imp/back` and `Main/home` hold (sizes per top-level folder), shares,
   snapshot and replication tasks with their last runs, the cloud sync logs, Garage
   per bucket, TrueNAS apps. GPU VM: mounts, bind mounts, the start delay, every
   stack with its volumes, where Jellyfin's media is. Write the facts into
   `inventory/` and new `systems/` pages. — gate: every current app has a row
   saying where its data is.
3. **Safety net:** the live data, its copy in `Main/repli`, and the old Google Drive
   copy (owner, 2026-11-14). The new backups get a tested restore as each app moves.
   — gate: `Main/repli`'s newest snapshot matches `imp/back`'s, checked in A2;
   if it is stale, a replication run first.
4. **Failures are seen:** TrueNAS alerts and backup jobs post to ntfy; a fresh Uptime
   Kuma on the VPS watches home from outside. — gate: a deliberately failed job
   reaches the owner's phone.

### B. Before the first internal app moves

1. **Storage layout:** free space on `Main` (prune Garage's old backups, remove
   `iocage`), create the dataset tree, snapshot and replication tasks per group,
   NFS defaults. Moving data into a different dataset is a copy, not a rename, so it
   briefly takes double space: move one folder at a time and delete the source after
   each (`imp` has about 455 GiB free). The owner expects the finished layout to use
   less space than today's, since each dataset gets one backup method instead of
   several copies. — gate: a test dataset is snapshotted, copied and browsable.
2. **`docker-1`** from OpenTofu and Ansible, with the NAS wait, the reconcile timer
   and the boot order. — gate: rebooting TrueNAS, and cold-booting the whole host,
   each bring a test container on NFS back without help.
3. **Arcane:** deploy a test stack from git, give it a secret from OpenBao, back up and
   restore its local volume. — gate: all three work, or their replacements are
   chosen.
4. **DNS and internal names:** a resolver (to be researched, owner 2026-11-14), one
   naming scheme for internal addresses, internal TLS by DNS challenge. — gate: a
   test name resolves with a valid certificate on the LAN and over Tailscale.
5. **Pilot:** one small internal app, end to end, then a skill
   (`skills/migrate-a-home-app/`) with the steps as they were done. — gate: the app
   runs from `apps/homeserver/<app>/`, and its data restore has been tested.

### C. Before the first public app

1. **Pangolin:** the VM, server, Newt at home, Cloudflare in front. — gate: a test
   app is reachable from outside, and survives a VPS reboot and a home IP change.
2. **Sign-in for apps without their own:** Pangolin's Badger or an Authentik outpost.
   — gate: a test app with no login asks for Authentik.

### D. Before an app with a Postgres database

1. **Home Pigsty node,** primary placement decided, and the outage drill: cut home's
   internet for 2 minutes and record what the cluster and a test app do. — gate: a
   test app's database is restored from pgBackRest onto it, and the drill is in
   `journal/`.

### Order of the apps

Small internal apps → the rest of the internal apps → public apps → apps with
Postgres → the GPU cutover → Nextcloud and Immich last, because they are the largest
and matter most. One app at a time; the old copy keeps running until the new one is
healthy. Some stacks are three years old and may be retired instead.

### After the last app

Remove the old GPU VM, Portainer, the SMB mounts and the start delay; turn off VM
backups for VMs that hold no data; the re-hardening pass (an audit with its own
journal entry).

## Portainer to git

Moved from `plans/migration.md`. Today every home stack exists only inside
Portainer: its Compose file and `.env` live in Portainer's database, not here.
The target: one directory per app, `apps/homeserver/<app>/compose.yaml`, with secrets and
identifying values as references and everything else written in (`apps/README.md`),
deployed by Arcane from that directory, so the repo — not the UI — is the source of
truth. Routing (labels or proxy entries) stays out of the Compose file, so an app can
move before its public route exists.

## Open, for the owner

- Where the Pigsty primary sits (after D1).
- Which DNS resolver (B4).
- Badger or an Authentik outpost (C2).
- Whether to keep BorgWarehouse once restic or Kopia handle offsite copies.
- The change to `decisions/backup-tiers.md` this design needs (proposed separately).

## Links

`plans/shared-postgres.md`, `plans/vps-foundations.md`, `plans/sablier-wakeups.md`,
`ideas/edge-and-security-layers.md`, `systems/backups.md`, `systems/oob.md`,
`decisions/backup-tiers.md`.
