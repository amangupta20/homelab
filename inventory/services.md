---
type: inventory
status: "documented, partially verified"
verified: "partially (Dokploy, OpenBao, Hermes WebUI and VPS apps verified 2026-10-26/27; others from docs/memory)"
hosts:
  - "[XCP-ng host](hosts.md)"
  - "[TrueNAS VM](hosts.md)"
  - "[Docker + proxy host](hosts.md)"
  - "[Remote VPS](hosts.md)"
related:
  - "[Hosts](hosts.md)"
  - "[Network](network.md)"
  - "[Backups](../systems/backups.md)"
  - "[OpenBao](../systems/openbao.md)"
tags:
  - inventory
  - services
  - docker
  - apps
---

# Services — what runs here

This file owns the service list. Other pages link here, never copy this table.

**Source:** every row is from the docs or the owner's memory and is not
verified against the live lab, unless its State says `verified: …`.
IPs live in `inventory/network.md` and hosts in `inventory/hosts.md`; "unknown" in the Host column means no
document says, and the read-only recon pass has not filled it in yet.

| Service | What it is | Host | State |
|---|---|---|---|
| Xen Orchestra | Web UI that manages all VMs: start/stop, snapshots, scheduled backups. | unknown | stable — sends alerts to ntfy |
| TrueNAS VM | Storage OS. Holds file shares and is the backup target for VM images. | XCP-ng host | stable — full clean-import restore still to test |
| Garage (S3) | S3-compatible object store, port 30188. Holds Dokploy backups and, once created, the OpenTofu state bucket. | TrueNAS VM | running — single node, no redundancy |
| BorgWarehouse | Web UI for BorgBackup. Used for app-level backups where a full VM image is not enough (e.g. inside Nextcloud). | TrueNAS VM | stable |
| Portainer CE | Web UI for the homeserver's Docker stacks. Every homeserver app is deployed from here today. | unknown | stable — replacement not decided, Arcane is the likely candidate |
| Nginx Proxy Manager | Reverse proxy: routes public traffic from Cloudflare to the right container by domain. | Docker + proxy host | in docs, not verified |
| apt cache | Package cache on port 3142 so local VMs don't re-download packages. Clients point at it in `/etc/apt/apt.conf.d/00proxy`. | Docker + proxy host | in docs, not verified |
| Fail2Ban | Bans brute-force IPs at the firewall by watching logs. | unknown | in docs, not verified |
| Tailscale | Private mesh VPN; the only admin path. | every admin-reachable machine | in docs, not verified |
| Supabase (self-hosted) | Shared Postgres/auth/storage backend for small apps. | unknown | in docs, not verified |
| ntfy bus | Push-notification service. Backup jobs, deploys, and security alerts post here. | unknown | stable — offsite "is the host itself down?" check still to do |
| Nextcloud AIO | Self-hosted file sync (Dropbox replacement), all-in-one container. | unknown | stable — full restore test still to do |
| Uptime Kuma | Up/down monitoring. Named once in the old platform page; nothing else mentions it. | unknown | unknown whether it runs |
| Dokploy | Deploys every app on the VPS (`systems/vps.md`). `apps/vps/openbao/` and `apps/vps/hermes-webui/` are in this repo; the rest are not yet. | remote VPS | running — verified: recon 2026-10-26 |
| OpenBao | Secret store. See `systems/openbao.md`. | remote VPS | running, unsealed — verified 2026-10-26 (`/v1/sys/health` 200); Dokploy reads it at deploy time, verified 2026-10-27; backup not set up yet |
| Hermes WebUI (second) | Chat web UI for someone without lab access: own container, volumes and password; `apps/vps/hermes-webui/`. | remote VPS | running — deployed 2026-10-27; login, provider and chat work (owner); backups not set up |
| OCI Borgmatic | Planned: run Borg backups on a cheap cloud VM. | — | design only — do not deploy yet |
| Object storage lab | Experiment: S3-compatible storage (Garage/SeaweedFS) across two sites. | — | idea, not built |

### Apps on the VPS

One row per Dokploy project, from Dokploy's service list and `docker ps -a`
on the VPS (recon 2026-10-26). "Containers" counts running / existing
containers under each app's Compose project name; 0/0 means none exist, so the
app is not running. What each app is for was not checked: names only. Whether
`ntfy` and `supa` here are the "ntfy bus" and "Supabase" rows above is not
checked either.

| Dokploy project | Services (containers running / existing) | Host | State |
|---|---|---|---|
| Coder | coder (0/0) | remote VPS | not running |
| gtnh | eudash (1/1) | remote VPS | running |
| hermes | hermes (2/2), hindsight (2/2), camofox (1/1) | remote VPS | running |
| jobops | app (0/0) | remote VPS | not running |
| kimai | app (2/2) | remote VPS | running |
| ntfy | ntfy (1/1) | remote VPS | running |
| Odyssues | odysseus (0/0), litellm (0/0), diagram mcp (0/0), geogebramcp (0/0) | remote VPS | not running |
| opendota | opendota (0/0) | remote VPS | not running |
| openwebui | open-webui (3/3), memory (0/2), githubmcp (0/1), oikb (0/1), office (0/0) | remote VPS | partly running |
| paperclip | paperclip (2/2) | remote VPS | running |
| pelican | pelican-dashboard (1/1) | remote VPS | running |
| router9 | 9router (2/2) | remote VPS | running |
| supa | supabase (13/13) | remote VPS | running |

How each service is backed up: `systems/backups.md`.

## To do

- WUD (What's Up Docker) for container-update notices — replaces Watchtower.
