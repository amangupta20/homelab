---
type: plan
tags:
  - plan
  - migration
  - storage
  - portainer-to-git
---

# Home overhaul

**Status:** in progress — A1 done 2026-11-14 (`lab/systems/oob.md`); A2, the read-only
recon, done 2026-11-14 (facts in `lab/inventory/` and `lab/systems/truenas.md`); A3 done
2026-11-15, after a rerun of a replication that failed on a checksum error in `imp`
(checked 2026-11-16); B4a phase 1, the home proxy, done 2026-11-18
(`agents/journal/2026-11-18-build-proxy-1-traefik.md`). Next: B2a, then B3 (order
revised 2026-11-23, see "B. Before the first internal app moves"). Replaces `agents/plans/migration.md`
(owner, 2026-11-14).

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

Read live on 2026-11-14; the details are in their owner files (`lab/inventory/hosts.md`,
`lab/inventory/services.md`, `lab/systems/truenas.md`, `lab/systems/backups.md`).

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

## Why the old setup is being replaced, and what was turned down

The owner's description, 2026-11-14, with what the recon confirmed:

- **One blob per share.** The important data (`imp/back`), the normal data
  (`Main/home`) and leftovers (`imp/norm`) are three large shares. A snapshot, a sync
  or a mount is all-or-nothing, so one bad file or a cut upload failed the whole
  Google Drive job, and two of the three Drive tasks failed most of the time.
- **Mounts held together by sleeps.** The GPU VM mounts the shares from `/etc/fstab`
  over SMB with `soft` mounts (a short NAS hiccup becomes a file error, not a pause),
  a systemd unit waits 300 s before mounting, Docker waits 320 s more, and containers
  bind-mount folders inside the shares.
- **Nothing alerts.** Snapshots and the replica stopped for 15 days without anyone
  being told.

Turned down, and why (owner, 2026-11-14):

- **restic for every dataset:** each app's own backup tool where it has one (Nextcloud's
  Borg), a ZFS copy otherwise.
- **A ZFS copy on top of an app's own backup:** two copies of the same data on `Main`
  waste space; one method per dataset.
- **A fresh B2 copy before migrating:** the safety net is the live data, the
  `Main/repli` copy and the old Google Drive copy; backups are set up and restore-tested
  as each app moves.
- **NFS for every app:** only the large-data apps; small state stays in local Docker
  volumes, where SQLite is safe and apps start without the NAS.
- **Read-only browsing for everything:** write access is decided per app (Jellyfin's
  media is writable).
- **Passing the onboard SATA controller to TrueNAS:** ruled out; an HBA card later.
- **Retention** in this design: critical datasets snapshotted daily and kept two weeks,
  with one copy on the other disk; normal data daily, one week, no copy; scratch none.
  Nextcloud's Borg keeps 7 days, 4 weeks and 6 months. The offsite tier follows
  `agents/decisions/backup-tiers.md`. Today's TrueNAS tasks already keep two weeks for
  `imp/back` and one for `Main/home` (`lab/systems/truenas.md`).

How convenient versus how locked down: `agents/rules/agent-access.md` — convenient by
default, with two hard guards (no agent credential can delete or overwrite backups; no
manual XCP-ng snapshot deletion). Restore tests carry the weight that lockdown would.

## Design

### One operating system

Every home VM built from code runs **Debian 13** (owner, 2026-11-16), from
Debian's official cloud image imported as one Xen Orchestra template, unless a
specific reason for one VM is written down here. Why: one OS means one Ansible
base, one set of package names and one upgrade rhythm. The old VMs were split
without a rule — Debian on the ones set up and left alone (NPM-set,
adguard-docker, apt-cache, `xo-ce`), Ubuntu 24.04 on the ones used often
(`gpu_docker`, portainer instance) (`lab/inventory/hosts.md`) — and the owner
does not know of a reason for the Ubuntu ones. Debian is also the lighter
of the two at idle, by roughly 50-100 MB (estimate, not measured).

To check before its VM is built, not assumed: `gpu-1`, the NVIDIA driver and
container toolkit for the GTX 1050 Ti on Debian 13. The Oracle Cloud machines
(Remote VPS, `pigsty-1`) run Ubuntu 24.04 and are not covered by this rule.

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
  (`agents/decisions/backup-tiers.md`). `Main/home` goes back to Google Drive, split into
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
  a sidecar writing `/run/secrets` does (`agents/decisions/open-questions.md`, "Container
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
home. Design and open choices: `agents/ideas/edge-and-security-layers.md`.

The VM should get a reserved public IP, so the Cloudflare records never change; an
ephemeral IP cannot be turned into a reserved one with the same address later.
Oracle does not document the free tier's reserved-IP limit; users report one.
Check the account's Service Limits page before creating the VM.

### Databases

Home apps' Postgres databases go to the shared Pigsty cluster
(`agents/plans/shared-postgres.md`), with a node at home. Only the primary takes writes.
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
fallback. Two limits, from the cluster layout in `agents/plans/shared-postgres.md`:

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

1. **A second way in.** Done 2026-11-14: `oob-1` (`lab/systems/oob.md`).
2. **Read-only recon.** Done 2026-11-14 ("Where things stand"). Not read yet: the
   size of each top-level folder in `back` and `home`, and Garage per bucket (needs
   Garage's admin token); both are read in B1, before any data moves.
3. **Safety net:** the live data, its copy in `Main/repli`, and the old Google Drive
   copy (owner, 2026-11-14). The new backups get a tested restore as each app moves.
   — gate: `Main/repli`'s newest snapshot is from after 2026-11-14 and matches
   `imp/back`'s. The 2026-10-30 copy was stale on 2026-11-14. On 2026-11-15 the
   snapshots ran again but the replication failed on a checksum error in `imp`;
   the damaged file and snapshot were removed and the replication rerun by hand
   (`lab/systems/notes/truenas.md`, "Checksum errors on `imp`"). **Done 2026-11-15**, checked
   2026-11-16 through the TrueNAS API: `Main/repli` and `imp/back` both have
   `auto-2026-11-15_20-00` as their newest snapshot, and the scrub of `imp` that
   followed found 0 errors.
4. **Nextcloud recovered.** Parked on 2026-11-14 until it moves (owner): containers
   stopped, and AIO's daily backup turned off, because AIO's nightly job (22:00 UTC)
   starts all containers after its backup. A Borg integrity check of all ten archives
   passed the same day. **2026-11-14 to -15, read on the GPU VM:** the owner restored
   it that evening (the data folder, an SMB mount of `back/nextcloud`, was rewritten
   around 19:30 UTC); the restore brought `daily_backup_time` (22:00) back, so the
   nightly backup ran, failed on the damaged file in `imp` (`lab/systems/notes/truenas.md`,
   "Checksum errors on `imp`") and then started every container. It ran on Nextcloud
   34.0.5 with `files_archive` 1.2.8 still installed until 2026-11-15, when the
   agent stopped all twelve containers at the owner's request and renamed
   `daily_backup_time` to `daily_backup_time.off-2026-11-15` so nothing restarts them.
   The owner restored the 2026-11-13 archive (owner, 2026-11-16), which is also
   the last good one (22:07 UTC). The move restores from
   it, and the daily backup is turned back on then. Before Nextcloud starts again, `custom_apps/files_archive`
   must be moved out of its volume: AIO always starts its newest image, which repeats
   the upgrade to Nextcloud 35 that this app broke. — gate: Nextcloud answers on
   Nextcloud 35, and the next nightly backup succeeds.
5. **Failures are seen:** TrueNAS alerts and backup jobs post to ntfy; a fresh Uptime
   Kuma on the VPS watches home from outside. — gate: a deliberately failed job
   reaches the owner's phone.
6. **Disk health is watched:** `smartd` on the XCP-ng host checks both passed-through
   hard disks and alerts to ntfy, because TrueNAS cannot read their SMART data
   (`lab/systems/truenas.md`). Both pools are single disks, so a failing disk must be seen
   early. SMART was read by hand on 2026-11-15 (both PASSED; recorded in
   `lab/systems/truenas.md`); `smartd`, the long self-tests and the ntfy alert are not set
   up yet. Later, these alerts and the hosts' metrics also go to a central monitoring
   system (which one is open). — gate: `smartctl` results for both disks are recorded,
   and a test alert reaches the owner's phone.

### B. Before the first internal app moves

**Order (owner, 2026-11-15):** the package and image cache comes before the agent VM.
Every VM built from code, and every CI runner, downloads the same packages and images
again; with the cache first, only the first download leaves home. The cache runs on its
own VM, which becomes the first VM built from code (`agents/plans/package-and-image-cache.md`).
A self-hosted git host does not wait for any of B: it can start on the VPS
(`agents/ideas/self-hosted-git.md`, pull request #79).

**Order from here (owner, 2026-11-23):** B2a (the bare `docker-1`) → B3 (Arcane on it)
→ B2b (the NAS wait, the reconcile timer and the boot order) → B5 (the pilot). Arcane
comes before the NAS plumbing because the reconcile timer is "`docker compose up -d`
or Arcane's equivalent", and whether Arcane reads OpenBao and backs up volumes decides
what else `docker-1` needs. B1 runs alongside the migration instead of before it.
Deferred, so none of them blocks the order above: agent-1's backups (B0), the dashboard
review and the Sablier wakeup test (both in B4a). The step numbers are unchanged
because other pages cite them.

00. **Package and image cache** on its own VM, the first VM built the new way: OpenTofu
    through Xen Orchestra, cloud-init for the first key, Ansible for the rest. Its steps
    and gates are in `agents/plans/package-and-image-cache.md`. — gate: that plan's step 3
    (a miss then a hit for one package and one image) passes on this VM.
0. **Agent VM** (`agent-1`), the second VM built from code, after the cache. It reuses
   the VM-from-code pipeline the cache VM proved, before `docker-1` and `gpu-1` depend on
   it, and it lets agents work in the lab around the clock instead of on the owner's
   laptop.
   - **Runs** (owner, 2026-11-14): Claude Code, Codex, opencode, Hermes and pi/omp,
     mostly as Orca workers; the owner drops the ones he stops using. Orca reaches it as
     a connected server, so workers start there from the owner's Orca. Docker for
     agents' test containers. It is also the owner's general development machine for
     AI-assisted work, including loops left running overnight, until his other project
     is up (owner, 2026-11-14). Long runs follow the owner's rule for jobs over 25
     minutes: an independent scheduled check, which this VM can host with systemd
     timers.
   - **Size:** see the agent-1 row in `lab/inventory/hosts.md` for the current disk
     and memory limits, and `iac/agent-vm.tf` for how OpenTofu handles those limits.
   - **A desktop on demand** (owner, 2026-11-22): headless browsers (Playwright,
     Chromium) for agents' screenshots and web tests, and one virtual display (TigerVNC
     with a light desktop) that starts only when an agent or the owner needs it, so the
     owner can watch or take over over VNC on the LAN or tailnet.
   - **Progress:** the VM was built on 2026-11-22 and has the base playbooks (guest
     agent, LAN cache client) and `ansible/agent.yml` (the owner's user, Docker, gh,
     mise with Node and the harnesses, all through the cache), with second runs
     changing nothing (`agents/journal/2026-11-22-build-agent-1.md`). The Orca server
     runs there, paired with the owner's Orca and kept on Orca's latest release by a
     timer (`agents/journal/2026-11-22-orca-server-agent-1.md`), and so does the
     Antigravity CLI, `agy` (owner, 2026-11-22; `agents/journal/2026-11-22-agy-agent-1.md`).
     Hermes is installed by its own installer, outside Ansible and the cache (owner,
     2026-11-22; `agents/journal/2026-11-22-hermes-agent-1.md`). The owner's agent
     config and Hindsight are on every harness, DeepSeek Harness is installed, and
     agent-1 is on the tailnet as `tag:agent`
     (`agents/journal/2026-11-22-agent-1-config-hindsight-dsh.md`). The desktop runs on
     demand, an Orca worker from the owner's Orca finished a read-only task there, and
     Claude Code's working setup is on it (`agents/journal/2026-11-22-agent-1-desktop-orca.md`). Still to do:
     backups (owner, 2026-11-22: decide later; 2026-11-23: deferred for longer, and
     nothing else in B waits on them).
   - **Network:** on the main tailnet with its own tag (`tag:agent`, owner 2026-11-22) and
     rules in `homelab-private`'s access policy, so it reaches what its rules allow.
   - **Access** follows `agents/rules/agent-access.md`; how agent-1's credentials are set up
     is the owner's decision (2026-11-22), recorded in `homelab-private`. No deleting or
     merging XCP-ng snapshots by hand.
   - **Backups:** the machine is rebuilt from the repo, but as a development machine
     its home folder holds work in progress and the harnesses' logins, so it is backed
     up: a low-frequency Xen Orchestra delta backup to start, or the home folder to
     Garage. Its harness logins are credentials, so the backup is treated like one.
     **To explore, not decided** (owner, 2026-11-22: "all that is just theory for now"):
     backing up only what cannot be rebuilt instead of whole-VM snapshots, for example
     targeted config backups or a file-level tool such as Kopia; or a second disk that
     holds the work (home folder, repositories), so the system disk is backed up or
     snapshotted on its own without churning snapshots of the work.
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
   - **Alongside the migration** (owner, 2026-11-23), not before it. The clean-up
     can happen at any time. An app whose data goes on NFS waits until its dataset
     exists, or its data is moved twice; so the first apps to move, the pilot
     included, are ones whose data stays in local Docker volumes.
2. **`docker-1`**, split in two around B3 (owner, 2026-11-23):
   - **2a.** The VM from OpenTofu and the base Ansible playbooks (guest agent, LAN
     cache client) plus Docker, the way `proxy-1` and `agent-1` were built. — gate: a
     second Ansible run changes nothing.
   - **2b.** After B3: the NAS wait, the reconcile timer (whatever B3 shows Arcane
     can do) and the boot order. — gate: rebooting TrueNAS, and cold-booting the
     whole host, each bring a test container on NFS back without help.
3. **Arcane**, on `docker-1` after 2a: deploy a test stack from git, give it a secret
   from OpenBao, back up and restore its local volume. — gate: all three work, or their
   replacements are chosen.
4. **Internal names and the home proxy.** Split in two (owner, 2026-11-17), so the
   names and certificates do not depend on whichever DNS resolver is being tried:
   - **4a. Home proxy: Traefik** (owner, 2026-11-17), the one reverse proxy for
     internal apps, on its own VM built from code (owner, 2026-11-17). Chosen
     for Sablier: Traefik loads its plugin without a custom build, and the VPS already
     runs it that way (`agents/plans/sablier-wakeups.md`); Pangolin is Traefik too.
     - **Order and progress** (owner, 2026-11-18): 4a goes ahead of B0, so the
       cache and the apps already deployed as code get names and sign-in first.
       Phase 1 done 2026-11-18: `proxy-1` built by OpenTofu, Traefik with the
       wildcard certificate and the route to `cache-1`
       (`apps/homeserver/traefik/`, `agents/journal/2026-11-18-build-proxy-1-traefik.md`).
       Verified over Tailscale and on the LAN. Since then: the cache's web UI signs
       in through Authentik (2026-11-18; its Grafana did too until it was removed on
       2026-11-22), Traefik's dashboard is behind forward-auth
       (2026-11-21), and so are traefik-log-dashboard and GoAccess
       (`agents/journal/2026-11-21-traefik-log-dashboard.md`). Still open: which log dashboards
       stay, and Sablier. Both deferred (owner, 2026-11-23): the dashboards are barely
       used yet, so there is no difference to judge; Sablier waits for the first
       migrated app that can sleep, and the wakeup part of this step's gate is checked
       then, not before the pilot.
     - **Names:** one public Cloudflare record, `*.home.<domain>`, pointing at the
       proxy's LAN address, so any resolver that forwards to the internet answers it,
       and over Tailscale through the subnet route (`agents/ideas/edge-and-security-layers.md`,
       "Internal names"). OpenWrt's dnsmasq drops public answers that point at private
       addresses by default (rebind protection). The Home router has it on, with no
       allowlist (`uci show dhcp`: `rebind_protection='1'`, no `rebind_domain`,
       2026-11-17). `home.<domain>` was added to its allowlist the same day
       (`uci add_list dhcp.@dnsmasq[0].rebind_domain`, previous file kept in
       `/root/dhcp.bak-20261117`). Tested 2026-11-18 with the real record: the
       router's dnsmasq answers `cache.home.<domain>` with the proxy's address
       (`agents/journal/2026-11-18-build-proxy-1-traefik.md`).
     - **Certificate:** one wildcard by DNS challenge through Cloudflare's API, the
       token in OpenBao. Nothing at home has to be reachable, and app names stay out
       of certificate-transparency logs.
     - **Routes as files** (owner, 2026-11-17): one file per app under the proxy's
       folder in this repo (hostname, then the app's `http://<address>:<port>`, as in
       Nginx Proxy Manager), deployed by Ansible. Traefik's file provider rereads them
       without a restart, and routes reach any VM, which a docker provider (one daemon
       only) cannot.
     - **Wakeups:** a Sablier with a socket proxy on each VM with sleepable apps, as on
       the VPS (`apps/vps/sablier/`); each route's middleware names its VM's Sablier
       (`sablierUrl`). Waking a container on another VM through a file route is
       **UNTESTED** (`agents/decisions/open-questions.md`, "Multi-node wakeups"). Traefik
       fetches the plugin from GitHub at start, which is slow from the LAN
       (`agents/decisions/open-questions.md`, the GitHub detour): pin it and keep the plugin
       cache on disk.
     - **View-only dashboards**, to try together and keep the ones used (owner,
       2026-11-17): Traefik's own dashboard (routes, services, middlewares, their
       state), traefik-log-dashboard (live traffic, a map of client locations, status
       codes and response times per service; AGPL-3.0; release 3.1.1 from 2026-04-14, GitHub
       releases, read 2026-11-21), and GoAccess (one report page from the access log). All
       three read Traefik's access log or API and edit nothing. Behind Authentik
       forward-auth through the local outpost (`apps/homeserver/traefik/NOTES.md`,
       "Forward-auth"), so they have no passwords of their own.
     - **First app:** `cache-1`'s web UI, which then signs in through Authentik (OIDC)
       at its `home.<domain>` name instead of with its own password; its Grafana did
       too until it was removed (2026-11-22). apt and Docker clients keep using its address.
     — gate: a test name has a valid certificate on the LAN and over Tailscale,
     whichever resolver answers; a stopped test container on another VM wakes through
     its route; the dashboards ask for Authentik.
   - **4b. Resolver: Technitium DNS Server** on two servers (owner, 2026-11-23). Nothing
     in 4a waits on it. **Progress:** the Pi's server runs since 2026-11-23, deployed
     by `ansible/oob.yml` (`apps/homeserver/technitium/`,
     `agents/journal/2026-11-23-technitium-oob-1.md`); since then it is the cluster's
     primary, and the router hands it out first by DHCP with itself second, forwarding
     its own DNS to the Pi first (owner's interim choice; `lab/systems/router.md`,
     "DNS"). The VPS node is defined in `apps/vps/technitium/`. Next: deploy and join
     it, put it in DHCP instead of the router, then the tailnet's nameservers. Researched 2026-11-23 by three research agents and checked by
     hand where noted; AdGuard Home, Pi-hole and Blocky were compared and set aside
     for now (owner).
     - **Two servers, same software** (owner, 2026-11-23): `oob-1`, the Raspberry Pi,
       as primary, since DNS is its only other job; the VPS as fallback. No lab
       container. Kept in step by Technitium's own clustering (since v14, changelog),
       over the tailnet.
     - **Both must answer the same:** a client stays on whichever server answered last
       until that one fails (`man systemd-resolved.service`, read 2026-11-23), and
       Tailscale asks every listed server at once and takes the first answer
       (`net/dns/resolver/forwarder.go`, `forwardWithDestChan`, read 2026-11-23). So
       the fallback carries real traffic. Blocklists, allowlist and local records are
       identical on both.
     - **Blocklists** (owner): HaGeZi Ultimate plus HaGeZi Threat Intelligence Feeds
       (TIF) Medium, about 570,000 entries (counted from the list files, 2026-11-23).
       Things that break go into an allowlist kept in this repo, so both servers get
       it. The full TIF list (about 2 million entries) is too big for the Pi; see the
       measurements below.
     - **Measured on 2026-11-23** in a throwaway Technitium 15.6.2 container on
       `agent-1`, capped at 900 MB to match the Pi (x86, so a guide for the Pi, not
       its own figure). Memory the process cannot give back (anonymous):
       Ultimate alone 82 MB; Ultimate + TIF Medium 252 MB after loading and 345 MB at
       the peak of a forced list update (319 MB after it); Ultimate + full TIF 670 MB,
       not released when TIF was removed. The Pi had 732 MB available (`free -m`,
       same day). Whether daily list updates keep raising memory was not tested; if
       they do, .NET's `DOTNET_GCHeapHardLimit` caps it (**UNTESTED**).
     - **Upstream:** DNS over HTTPS to public resolvers; cached answers came back in
       about 1.4 ms and uncached ones in about 90 ms in the same test (dnsperf, one
       client, not a benchmark).
     - **Local records:** `*.home.<domain>` answered locally with the proxy's address,
       so internal names work without the internet while the Pi is up.
     - **LAN clients** get the Pi first and the VPS second from the router's DHCP and
       ask them directly, so the Pi's query log shows each device; through the router,
       every query would show the router. LAN clients reach the VPS through the
       router's Tailscale (**UNTESTED**). With the Pi down and home's internet down
       too, the LAN has no DNS; accepted (owner, 2026-11-23).
     - **IPv6 gap to close:** the router relays the ISP router's IPv6 announcements
       (`uci show dhcp`: `ra='relay'`, 2026-11-23), so clients may also learn the
       ISP's IPv6 resolvers and skip the blocklists. Not yet seen on a client.
     - **Tailnet clients** (owner, 2026-11-23): both servers as the tailnet's global
       nameservers, with "override local DNS" on, so devices away from home are
       blocked too, and the VPS keeps answering when home is down. No public
       resolver in that list: it would win some of the races and skip blocking.
       Servers on the tailnet (agent-1, the VPS itself) must not take the tailnet's
       DNS (`--accept-dns=false`); which ones do is to be checked before override is
       turned on. Port 53 and Technitium's console on the VPS listen on the tailnet
       only. Queries from home over the subnet route arrive as the router's address
       (its Tailscale translates source addresses, `NoSNAT: false`, 2026-11-23).
     - **Dashboard, to try:** Resolvr (`bassem-elsodany/resolvr-dns-dashboard`, MIT,
       v1.3.2 from 2026-10-12, GitHub), a read-mostly dashboard on Technitium's API with
       cluster views, at home behind Authentik with its own narrow API token; not on
       the VPS (owner). Technitium's own console stays for settings. The repo, not
       either UI, is where lists live.
     - **The Pi:** Technitium in Docker (owner, 2026-11-23: one image pin for the Pi
       and the VPS), through the LAN cache's Docker Hub remote, with host networking
       and Docker's own firewall rules off; details in `lab/systems/oob.md`, "DNS
       resolver". Its firewall opens DNS to the LAN, which changes it from a
       single-purpose recovery box. The Pi and its card are rebuilt from code, so a
       dead card is a reflash (owner, 2026-11-23).
     - **The Pi is on the other tailnet** (`lab/systems/oob.md`), so the main tailnet
       reaches it like any home VM: by its LAN address through the router's subnet
       route. Checked over SSH on 2026-11-23: the VPS takes subnet routes and sends
       the Pi's address into the tailnet; the Pi's own Tailscale claims only its one
       peer and `100.100.100.100` (`ip route show table 52`), so traffic to the VPS
       leaves through the router. So the tailnet's nameservers are the Pi's LAN
       address and the VPS's tailnet address, and the cluster talks the same way. The
       Pi sees the VPS and tailnet clients as the router; its firewall opens the
       cluster port to the router's address when the VPS node is added. The main
       tailnet's access rules must allow both paths (not checked; they are in
       `homelab-private`). Cost: all of this depends on the router's Tailscale.
     — gate: both servers answer the same for a blocked name, an allowlisted name and a
     `home.<domain>` name; stopping the Pi leaves LAN and tailnet clients resolving
     through the VPS; the Pi stays under its memory budget through a week of daily list
     updates.
5. **Pilot:** one small internal app whose data stays in local Docker volumes (see
   B1), end to end, then a new skill
   in `agents/skills/` (working name `migrate-a-home-app`) with the steps as they were done. — gate: the app
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
   `agents/journal/`.

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
per-user libraries. Candidates, verdicts and trade-offs: `agents/ideas/debrid-streaming.md`. — gate: the owner
picks one, or keeps Jellyfin with local media.

### After the last app

Remove the old GPU VM, Portainer, the SMB mounts and the start-up sleeps; turn off VM
backups for VMs that hold no data; the re-hardening pass (an audit with its own
journal entry).

## Portainer to git

Moved from `agents/plans/migration.md`. Today every home stack that predates this
plan exists only inside Portainer: its Compose file and `.env` live in Portainer's database, not here.
The target: one directory per app, `apps/homeserver/<app>/compose.yaml`, with secrets and
identifying values as references and everything else written in (`apps/README.md`),
deployed by Arcane from that directory, so the repo — not the UI — is the source of
truth. Routing (labels or proxy entries) stays out of the Compose file, so an app can
move before its public route exists.

## Open, for the owner

- Where the Pigsty primary sits (after D1).
- Which tailnet machines take the tailnet's DNS today, before override is turned on
  (B4b). The resolver itself is chosen: Technitium on the Pi and the VPS (2026-11-23).
- Badger or an Authentik outpost (C2).
- Whether to keep BorgWarehouse once restic or Kopia handle offsite copies.
- The change to `agents/decisions/backup-tiers.md` this design needs (proposed separately).
- How to recover Nextcloud (A4).
- What the clean-up removes (B1).

## Links

`agents/plans/shared-postgres.md`, `agents/plans/vps-foundations.md`, `agents/plans/sablier-wakeups.md`,
`agents/ideas/edge-and-security-layers.md`, `lab/systems/backups.md`, `lab/systems/oob.md`,
`lab/systems/truenas.md`, `agents/ideas/debrid-streaming.md`,
`agents/decisions/backup-tiers.md`.
