---
type: inventory
status: "documented, partially verified"
verified: "partially (Dokploy, OpenBao, Hermes WebUI and VPS apps verified 2026-10-26/27/29; Home network DHCP and DNS verified 2026-11-13 over SSH; others from docs/memory)"
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
| Xen Orchestra | Web UI that manages all VMs: start/stop, snapshots, scheduled backups (`systems/backups.md`). | Xen Orchestra (`xo-ce`) | running — verified: REST API 2026-11-14; ntfy alerts in docs, not verified |
| TrueNAS VM | Storage OS: pools, file shares, snapshots and replication (`systems/truenas.md`). | XCP-ng host | running — verified: TrueNAS API 2026-11-14; full clean-import restore still to test |
| Garage (S3) | S3-compatible object store, port 30188. Holds Dokploy backups and, once created, the OpenTofu state bucket. A TrueNAS app; data in `Main/S3_Garage`, 345 GiB. | TrueNAS VM | running — verified: TrueNAS API 2026-11-14; single node, no redundancy |
| BorgWarehouse | Web UI for BorgBackup. Holds Nextcloud AIO's own Borg backups (about 59 GB after deduplication). A TrueNAS app; data in `Main/borgwarehouse`. | TrueNAS VM | running — verified: TrueNAS API and the Nextcloud backup log, 2026-11-14 |
| Portainer CE | Web UI for the homeserver's Docker stacks: 7 Docker hosts (4 reachable) and 32 stacks. Every homeserver app is deployed from here today. | portainer instance | running — verified: API 2026-11-14; to be replaced by Arcane (`plans/home-overhaul.md`) |
| Nginx Proxy Manager | Reverse proxy: routes public traffic from Cloudflare to the right container by domain. | Docker + proxy host | in docs, not verified |
| apt cache | Package cache on port 3142 so local VMs don't re-download packages. Clients point at it in `/etc/apt/apt.conf.d/00proxy`. | Docker + proxy host | in docs, not verified |
| Fail2Ban | Bans brute-force IPs at the firewall by watching Nginx Proxy Manager's logs and the host's SSH log. | NPM-set | running — verified: Portainer API 2026-11-14 |
| Home network DHCP and DNS | dnsmasq on the router: hands out addresses on the home subnet and forwards DNS (`systems/router.md`). | Home router | running — verified: `uci show dhcp`, leases in `logread`, 2026-11-13 |
| Tailscale | Private mesh VPN; the only admin path. | every admin-reachable machine | in docs, not verified |
| Shared Postgres (Pigsty) | Postgres 18 cluster, with monitoring, for apps to share (`plans/shared-postgres.md`). Blinko runs on it as a test. | `pigsty-1` | running since 2026-11-06; restore and alert drills passed |
| Blinko | Note-taking app, to test the shared Postgres (`apps/vps/blinko/`). Public domain, behind its own login. Stops after 20 idle minutes (Sablier). | remote VPS, database on `pigsty-1` | running since 2026-11-07, as a test |
| Supabase (self-hosted) | Shared Postgres/auth/storage backend for small apps. | unknown | in docs, not verified |
| ntfy bus | Push-notification service. Backup jobs, deploys, and security alerts post here. | unknown | stable — offsite "is the host itself down?" check still to do |
| Nextcloud AIO | Self-hosted file sync (Dropbox replacement), all-in-one container. Data folder on the TrueNAS share `back` (`imp/back/nextcloud`); daily Borg backup at 22:00 to BorgWarehouse. | gpu_docker | down since 2026-11-13 22:56 UTC: its automatic update failed (read from the container's log 2026-11-14); full restore test still to do |
| Uptime Kuma | Up/down monitoring. One copy ran on the Raspberry Pi until its rebuild on 2026-11-14 (`journal/2026-11-14-rebuild-oob-pi.md`); another runs on the Portainer host. A fresh one on the VPS is planned. | portainer instance | running — verified: Portainer API 2026-11-14 |
| Sablier | Stops idle apps and starts them on the next request (`plans/sablier-wakeups.md`, `apps/vps/sablier/`). | remote VPS | running since 2026-11-07; Blinko, pgAdmin and CloudBeaver sleep behind it |
| Authentik | Single sign-on for the lab (`apps/vps/authentik/`). Public login; admin interface on a tailnet-only hostname. Mail through Resend. | remote VPS, database on `pigsty-1` | running since 2026-11-10 — verified: both containers healthy, public login 200, admin paths 403 publicly, admin hostname 403 from the public address; first app sign-in: Langfuse 2026-11-10 |
| Langfuse | The AI reviewer's trace viewer and evaluation tool (`apps/vps/langfuse/`). Public, sign-in through Authentik only. Stops after 20 idle minutes (Sablier). Event files in a B2 bucket. | remote VPS, database on `pigsty-1` | running since 2026-11-10 — verified: four containers healthy, public health 200 with a Let's Encrypt certificate, password sign-up 422 and login 401, Sablier wake 27–35 s; owner's first sign-in worked and a probe trace went in over OpenTelemetry 2026-11-10; no real traces yet |
| pg-proxy | One address on the VPS for the shared Postgres (`apps/vps/pg-proxy/`): 5432 for apps, 5436 for the database UIs. | remote VPS | running since 2026-11-09 — verified: a login as `blinko` through `pg-proxy:5432` reached the primary, and `dbuser_owner` through 5436 |
| pgAdmin | Web UI for the shared Postgres (`apps/vps/pgadmin/`). Tailnet only. | remote VPS | running since 2026-11-09 — verified: 200 over the tailnet, 403 from the public address |
| CloudBeaver | Web UI for the shared Postgres (`apps/vps/cloudbeaver/`). Tailnet only. | remote VPS | running since 2026-11-09 — verified: 200 over the tailnet, 403 from the public address, setup wizard skipped |
| Dokploy | Deploys every app on the VPS (`systems/vps.md`). `apps/vps/openbao/`, `apps/vps/hermes-webui/`, `apps/vps/blinko/`, `apps/vps/sablier/`, `apps/vps/pg-proxy/`, `apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`, `apps/vps/authentik/` and `apps/vps/langfuse/` are in this repo; the rest are not yet. | remote VPS | running — verified: recon 2026-10-26 |
| OpenBao | Secret store. See `systems/openbao.md`. | remote VPS | running, unsealed — verified 2026-10-26 (`/v1/sys/health` 200); Dokploy reads it at deploy time, verified 2026-10-27; backup to Garage S3 and restore verified 2026-10-29 (`journal/2026-10-29-restore-test-openbao.md`) |
| Hermes WebUI (second) | Chat web UI for someone without lab access: own container, volumes and password; `apps/vps/hermes-webui/`. | remote VPS | running — deployed 2026-10-27; login, provider and chat work (owner); backups not set up |
| Immich | Photo and video library. Library on the TrueNAS share `back` (`imp/back/immich`); its Postgres (with VectorChord) and machine learning on local disk, machine learning on the GPU. | gpu_docker | running — verified: SSH 2026-11-14 |
| Jellyfin | Media server. Media on the TrueNAS share `home` (`Main/home/media`), config and cache on local disk; transcodes on the GPU. | gpu_docker | running — verified: SSH 2026-11-14 |
| AdGuard Home | DNS ad blocker. Whether any device uses it is not checked. | adguard-docker | running — verified: Portainer API 2026-11-14 |
| wg-easy | WireGuard server with a web UI. | portainer instance | running — verified: Portainer API 2026-11-14; who uses it not checked |
| Homepage, MySpeed | A start page, and a speed-test logger. | gpu_docker | running — verified: SSH 2026-11-14 |
| Ollama | Local language-model runner, installed on the host, not in Docker. | gpu_docker | enabled as a service — verified: SSH 2026-11-14 |
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
| openwebui | open-webui (3/3), memory (0/2), githubmcp (0/1), oikb (0/1), office (0/0) | remote VPS | partly running |
| paperclip | paperclip (2/2) | remote VPS | running |
| pelican | pelican-dashboard (1/1) | remote VPS | running |
| router9 | 9router (2/2) | remote VPS | running |
| supa | supabase (13/13) | remote VPS | running |

How each service is backed up: `systems/backups.md`.

## To do

- WUD (What's Up Docker) for container-update notices — replaces Watchtower.
- When monitoring is set up (`decisions/open-questions.md`, Observability):
  scrape Mattermost's metrics. Its Performance Monitoring was turned on in the
  System Console on 2026-10-29 (owner), which serves Prometheus metrics on the
  container's port 8067. Nothing collects them yet.
