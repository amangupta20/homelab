---
type: plan
status: "in progress (A1 and A2 done, A3 waits on the next replication run)"
verified: "partially (A1 verified 2026-11-14; A2 read live 2026-11-14 through the Xen Orchestra, TrueNAS and Portainer APIs and SSH)"
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
recon, done 2026-11-14 (facts in `inventory/` and `systems/truenas.md`); A3 waits on
the next replication run. Replaces `plans/migration.md` (owner, 2026-11-14).

**Goal:** move every home workload to a setup where each app's data has one known
place and one known backup method, app definitions live in this repo and deploy
through Arcane, and public apps are reached through Pangolin — so later changes are
one app at a time, not another overhaul.

**Done when:** every home app runs from `apps/homeserver/<app>/` on `docker-1` or `gpu-1`
with a tested restore of its data; public apps go through Pangolin; the old GPU VM,
the SMB-mount setup, the start-up sleeps (300 s before the mounts, 320 s before
Docker) and Portainer are gone; and the
re-hardening pass (step 3 of the old plan) has a journal entry.

Decisions on this page are the owner's, made in conversation on 2026-11-14, unless a
line says otherwise. Anything marked **UNTESTED** has not been run here.

## Where things stand (2026-11-14)

Read live on 2026-11-14; the details are in their owner files (`inventory/hosts.md`,
`inventory/services.md`, `systems/truenas.md`, `systems/backups.md`).

**Machines.** Seven VMs run on the XCP-ng host: TrueNAS, `gpu_docker` (most apps),
`portainer instance`, `NPM-set`, `adguard-docker`, `apt-cache` and `xo-ce`. Six more
are stopped (`Dokploy`, `Minecraft`, `arkserver`, `zorin os test`, two `XOA`). No VM
has a start order or delay in XCP-ng, which is why `gpu_docker` sleeps before
mounting its shares and again before starting Docker.

**Storage.** TrueNAS gets the 1 TB and 2 TB disks whole (XCP-ng `udev` passthrough).

| Pool | Used / size | Datasets |
|---|---|---|
| `imp` (1 TB) | 0.43 / 0.91 TiB | `back` 431 GiB, `norm` 16 GiB, `ioapp` 9 GiB |
| `Main` (2 TB) | 1.38 / 1.81 TiB (76%) | `home` 650 GiB, `repli` 413 GiB, `S3_Garage` 345 GiB, `borgwarehouse` 55 GiB, empty `iocage` |

Snapshots and the `imp/back` to `Main/repli` replica last ran 2026-10-30; the
Google Drive sync tasks were deleted by the owner on 2026-11-14.

**Where each running app's data is today:**

| App | Runs on | Data today | Backed up today |
|---|---|---|---|
| Nextcloud AIO | `gpu_docker` | data folder on SMB `back/nextcloud`; its Postgres and config in local Docker volumes | its own Borg, nightly, to BorgWarehouse on `Main` |
| Immich | `gpu_docker` | library on SMB `back/immich`; Postgres in a local folder | the library through `imp/back`'s snapshots and replica; the local Postgres folder only through Xen Orchestra's VM backup |
| Jellyfin | `gpu_docker` | media on SMB `home/media`; config (2.9 GB) local | VM backup only for the config |
| Homepage, MySpeed, Ollama | `gpu_docker` | local | VM backup |
| Portainer, Uptime Kuma, wg-easy | `portainer instance` | local Docker volumes | VM backup |
| Nginx Proxy Manager, Fail2Ban | `NPM-set` | local folders | VM backup |
| AdGuard Home | `adguard-docker` | local volumes | VM backup |
| apt-cacher-ng | `apt-cache` | local | VM backup |
| Garage, BorgWarehouse | TrueNAS (apps) | `Main/S3_Garage`, `Main/borgwarehouse` | none of their own |

Paperless and Kavita keep files in `back` (`paperless`, `Books`) but have been
stopped for over a year, like about 35 other containers on `gpu_docker` (the old
Sonarr/Radarr stack, tdarr, wg-easy, drop-game and more) and a NetBox stack on the
Portainer host. Portainer still lists three Docker hosts that are offline (the old
Raspberry Pi, `coder`, `kasm`).

**Nextcloud has been down since 2026-11-13 22:56 UTC.** Its nightly automatic update
to Nextcloud 35 succeeded, then the third-party app `files_archive` failed its database
migration ("Trait ... StorageIdTrait not found") and the container restarts in a
loop. The Borg backup from 22:07–22:41 that night succeeded. The owner decides how
to recover; it gets a journal entry.

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
- **Nextcloud's own settings when it moves** (owner, 2026-11-14): it leaves the GPU
  VM for a VM with dynamic memory; ClamAV off (about 1 GB of RAM for little use
  here); office suite decided then — none, or Euro-Office for Microsoft files,
  instead of today's Collabora; the deprecated Docker Socket Proxy off unless an
  ExApp needs it. Add two AIO community containers: **Borg Backup Viewer** (browse
  and pull files from the Borg archives; helps restore tests) and, once central
  monitoring exists, the **Prometheus Nextcloud Exporter**. Other apps stay out of
  AIO's community containers and run as their own stacks. The owner's parents use
  Nextcloud too, so its downtime and restore test matter.
- **Immich and Nextcloud photos** (not decided): Immich can read a Nextcloud user's
  photo folder as a read-only external library, and the third-party Nextcloud app
  `integration_immich` shows the Immich library inside Nextcloud. Untested here.
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
  GPU (Jellyfin transcoding, Immich machine learning, AI) and nothing else (owner,
  2026-11-14). Both are built from this repo: OpenTofu for the VM,
  cloud-init for the first key, Ansible for the rest. Their local volumes are backed
  up per app; until each of those restores has been tested, `docker-1` also keeps a
  low-frequency Xen Orchestra delta backup. VM backups end once every app on a VM has
  a tested data restore.
- **GPU cutover:** a passed-through GPU can be attached to one running VM only. Once
  the non-GPU apps have moved, shut down the old GPU VM, attach the GPU to `gpu-1`,
  start it. Rollback is the reverse. The old VM stays powered off until the owner is
  satisfied, then is deleted.
- **Boot order in XCP-ng:** TrueNAS first, the Docker VMs after a delay; today no VM
  has one.
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
2. **Read-only recon.** Done 2026-11-14 ("Where things stand"). Not read yet: the
   size of each top-level folder in `back` and `home`, and Garage per bucket (needs
   Garage's admin token); both are read in B1, before any data moves.
3. **Safety net:** the live data, its copy in `Main/repli`, and the old Google Drive
   copy (owner, 2026-11-14). The new backups get a tested restore as each app moves.
   — gate: `Main/repli`'s newest snapshot is from after 2026-11-14 and matches
   `imp/back`'s. The 2026-10-30 copy was stale on 2026-11-14; the daily 19:00
   snapshot and replication should bring it current.
4. **Nextcloud recovered.** The owner restored the 2026-11-13 22:07 UTC backup on
   2026-11-14 and keeps its containers stopped until it moves (owner). AIO's nightly
   job runs at 22:00 UTC. Before Nextcloud starts again, `custom_apps/files_archive`
   must be moved out of its volume: AIO always starts its newest image, which repeats
   the upgrade to Nextcloud 35 that this app broke. — gate: Nextcloud answers on
   Nextcloud 35, and the next nightly backup succeeds.
5. **Failures are seen:** TrueNAS alerts and backup jobs post to ntfy; a fresh Uptime
   Kuma on the VPS watches home from outside. — gate: a deliberately failed job
   reaches the owner's phone.
6. **Disk health is watched:** `smartd` on the XCP-ng host checks both passed-through
   hard disks and alerts to ntfy, because TrueNAS cannot read their SMART data
   (`systems/truenas.md`). Both pools are single disks, so a failing disk must be seen
   early. Later, these alerts and the hosts' metrics also go to a central monitoring
   system (which one is open). — gate: `smartctl` results for both disks are recorded,
   and a test alert reaches the owner's phone.

### B. Before the first internal app moves

0. **Agent VM** (`agent-1`), the first VM built the new way. It is the cheapest place to
   make the VM-from-code pipeline work (OpenTofu through Xen Orchestra, cloud-init for
   the first key, Ansible for the rest) before `docker-1` and `gpu-1` depend on it, and
   it lets agents work in the lab around the clock instead of on the owner's laptop.
   - **Runs** (owner, 2026-11-14): Claude Code, Codex, opencode, Hermes and pi/omp,
     mostly as Orca workers; the owner drops the ones he stops using. Orca reaches it as
     a connected server, so workers start there from the owner's Orca. Docker for
     agents' test containers.
   - **Size** (proposed): 4 CPUs, 8 GB RAM, about 80 GB on the `Nvme` repository. The
     running VMs take about 22 GB of the host's 40 GB.
   - **Network:** on the main tailnet with its own tag (for example `tag:agent`) and
     rules in `homelab-private`'s access policy, so it reaches what its rules allow.
   - **Access** follows `decisions/agent-access.md`: convenient by default, with its own
     OpenBao policy that holds **no credential able to delete or overwrite backups**
     (no deleting Garage or B2 keys, nothing that writes to BorgWarehouse or the Xen
     Orchestra backup location), and no deleting or merging XCP-ng snapshots by hand.
   - **Holds no data worth backing up:** rebuilt from the repo; agents' work lives in
     git and in Hindsight.
   — gate: the VM is created by `tofu apply` and configured by Ansible from this repo;
   a second Ansible run changes nothing; an Orca worker started on it from the owner's
   Orca finishes a read-only task; its OpenBao token is refused when it asks for a
   backup credential.
1. **Clean-up and storage layout:** the owner decides, item by item, what goes: the
   stopped containers and stacks on `gpu_docker` and the Portainer host, the six
   stopped VMs, the offline Portainer hosts, leftover Docker volumes. Then free space
   on `Main` (prune Garage's old backups, remove `iocage`), read the folder sizes in
   `back` and `home`, create the dataset tree, snapshot and replication tasks per group,
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

### Later: a disk controller for TrueNAS

TrueNAS gets each hard disk through XCP-ng's `udev` passthrough, so it sees no
model, serial or SMART data. Passing a whole disk controller to TrueNAS fixes that.
The motherboard's own SATA controller is ruled out (owner, 2026-11-14); the plan is
an HBA card (for example a used LSI 9207-8i in IT mode), much later. Before buying
one: check on the XCP-ng host which PCIe slot is free next to the GPU, and that the
slot's IOMMU group holds nothing else, since XCP-ng cannot split groups. The switch
itself: shut TrueNAS down after a fresh replica, remove the disks from the
`Pass_Drives` repository, pass the card through; ZFS finds `imp` and `Main` by the IDs
on the disks. **UNTESTED**. — gate: TrueNAS shows both disks with their serials and
SMART data, and both pools are online.

### Later: streaming from TorBox

After the GPU cutover, try streaming from TorBox on `gpu-1` with nothing stored:
Remux on its own; Decypharr feeding Remux (Sonarr/Radarr choose, Decypharr adds and
exposes only those items, Remux reads them); and Rex, the one with seek-bar
thumbnails. Compare start time, seeking, transcoding to a phone over Tailscale, and
per-user libraries. Candidates and why: `ideas/apps-to-try.md`. — gate: the owner
picks one, or keeps Jellyfin with local media.

### After the last app

Remove the old GPU VM, Portainer, the SMB mounts and the start-up sleeps; turn off VM
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
- How to recover Nextcloud (A4).
- The agent VM's size and tag (B0).
- What the clean-up removes (B1).
- The "Docker + proxy host" rows that disagree with the live lab
  (`decisions/open-questions.md`, "Home VMs").

## Links

`plans/shared-postgres.md`, `plans/vps-foundations.md`, `plans/sablier-wakeups.md`,
`ideas/edge-and-security-layers.md`, `systems/backups.md`, `systems/oob.md`,
`systems/truenas.md`, `ideas/apps-to-try.md`,
`decisions/backup-tiers.md`.
