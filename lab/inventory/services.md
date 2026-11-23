---
type: inventory
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
IPs live in `lab/inventory/network.md` and hosts in `lab/inventory/hosts.md`; "unknown" in the Host column means no
document says, and the read-only recon pass has not filled it in yet.

| Service | What it is | Host | State |
|---|---|---|---|
| Xen Orchestra | Web UI that manages all VMs: start/stop, snapshots, scheduled backups (`lab/systems/backups.md`). | Xen Orchestra (`xo-ce`) | running — verified: REST API; ntfy alerts in docs, not verified |
| TrueNAS VM | Storage OS: pools, file shares, snapshots and replication (`lab/systems/truenas.md`). | XCP-ng host | running — verified: TrueNAS API; full clean-import restore still to test |
| Garage (S3) | S3-compatible object store, port 30188. Holds Dokploy backups and, once created, the OpenTofu state bucket. A TrueNAS app; data in `Main/S3_Garage`, 345 GiB. | TrueNAS VM | running — verified: TrueNAS API; single node, no redundancy |
| BorgWarehouse | Web UI for BorgBackup. Holds Nextcloud AIO's own Borg backups (about 59 GB after deduplication). A TrueNAS app; data in `Main/borgwarehouse`. | TrueNAS VM | running — verified: TrueNAS API and the Nextcloud backup log |
| Portainer CE | Web UI for the homeserver's Docker stacks: 7 Docker hosts (4 reachable) and 32 stacks. The long-standing home stacks are still deployed from here; the apps on `cache-1` and `proxy-1` deploy from code (`ansible/cache.yml`, `ansible/proxy.yml`). | portainer instance | running — verified: API; to be replaced by Arcane (`agents/plans/home-overhaul.md`) |
| Nginx Proxy Manager | Reverse proxy: routes public traffic from Cloudflare to the right container by domain. | NPM-set | running — verified: SSH and Portainer API |
| Artifact Keeper | Pull-through cache for apt packages (Debian, Debian security, Docker's, Raspberry Pi's, Tailscale's and mise's apt repositories), container images (Docker Hub, ghcr.io), npm and Python packages and plain files (Node's tarballs, GitHub releases, the Antigravity CLI), with an 80 GB ceiling in total; plain HTTP on port 80, LAN only (`apps/homeserver/artifact-keeper/`). Clients: `oob-1` (apt; `agents/journal/2026-11-17-cache-ceiling-and-oob-apt.md`), `proxy-1` and `agent-1` (`agents/journal/2026-11-22-cache-npm-node-github-mise.md`). | cache-1 | running — verified: deployed and tested (`agents/journal/2026-11-16-deploy-artifact-keeper.md`) |
| Traefik (home proxy) | Reverse proxy for internal apps at `<app>.home.<zone>`, one wildcard Let's Encrypt certificate by DNS challenge; routes are files in `apps/homeserver/traefik/routes/`. First route: `cache.home.<zone>` to `cache-1`, whose web UI signs in through Authentik (OIDC). Forward-auth through a local Authentik outpost (same stack) for apps without single sign-on; first: Traefik's dashboard at `traefik.home.<zone>`; then the view-only dashboards of the access log, traefik-log-dashboard at `traefik-logs.home.<zone>` and GoAccess at `goaccess.home.<zone>`. | `proxy-1` | running — verified: HTTPS 200 with a valid certificate over Tailscale and on the LAN (`agents/journal/2026-11-18-build-proxy-1-traefik.md`); the dashboard sends a request without a session to Authentik, and errors when the outpost is down (`curl`; `agents/journal/2026-11-21-home-traefik-dashboard-sign-in.md`); the log dashboards the same (`agents/journal/2026-11-21-traefik-log-dashboard.md`) |
| apt cache | Package cache on port 3142 so local VMs don't re-download packages. apt-cacher-ng, no Docker. Clients point at it in `/etc/apt/apt.conf.d/00proxy` (in docs, not verified). | apt-cache | running — verified: SSH |
| Fail2Ban | Bans brute-force IPs at the firewall by watching Nginx Proxy Manager's logs and the host's SSH log. | NPM-set | running — verified: Portainer API |
| Home network DHCP and DNS | dnsmasq on the router: hands out addresses on the home subnet, with the Pi's Technitium as first DNS server and the VPS's as second, and forwards its own DNS the same way (`lab/systems/notes/router.md`, "DNS through the Pi"). | Home router | running — verified: `uci show dhcp`, leases in `logread` |
| Technitium (home DNS) | DNS resolver with ad and tracker blocking (HaGeZi Ultimate + TIF Medium), a cache, DNS over HTTPS upstreams and the `home` zone; web console at `dns.home.<zone>` behind Authentik, or on port 5380 from the home subnet (`apps/homeserver/technitium/`). Primary node of the DNS cluster; the router hands it out by DHCP and forwards to it. | oob-1 | running — verified: `dig` from the LAN, blocked and allowed names and a `home` name (`agents/journal/2026-11-23-technitium-oob-1.md`) |
| Technitium (DNS fallback) | The DNS cluster's secondary node and fallback resolver, on the VPS's tailnet address only (`apps/vps/technitium/`); takes its settings and zones from the Pi; second DNS server for the LAN. | remote VPS | running — verified: blocked, allowed and `home` names over the tailnet, cluster sync, failover with the Pi stopped (`agents/journal/2026-11-23-deploy-technitium-vps.md`) |
| Resolvr | Dashboard for the Technitium DNS cluster at `resolvr.home.<zone>`, behind Authentik with no login of its own (`apps/homeserver/traefik/NOTES.md`, "Resolvr"). | proxy-1 | running — verified: `curl` through the proxy, connected to the cluster (`agents/journal/2026-11-23-resolvr.md`) |
| Orca server | Orca's server-only build (`orca serve`), so Orca workers start on agent-1 from the owner's Orca and keep running while his laptop sleeps. A systemd user service on port 6768, LAN and tailnet addresses only, each client paired with its own revocable token; a timer keeps it on Orca's latest release (`ansible/agent.yml`). | agent-1 | running — verified: `orca status --environment agent-1` from the owner's Orca (`agents/journal/2026-11-22-orca-server-agent-1.md`) |
| agent-1 desktop | One TigerVNC display with Xfce for watching or taking over agents; starts when someone connects to port 5901 and stops after 30 idle minutes. TLS and a VNC password (OpenBao, `kv/homelab/agent-1-vnc`); LAN and tailnet only (`ansible/agent.yml`). | agent-1 | runs on demand — verified: a connection started it (`agents/journal/2026-11-22-agent-1-desktop-orca.md`) |
| Tailscale | Private mesh VPN; the only admin path. | every admin-reachable machine | in docs, not verified |
| Shared Postgres (Pigsty) | Postgres 18 cluster, with monitoring, for apps to share (`agents/plans/shared-postgres.md`). Blinko runs on it as a test. | `pigsty-1` | running; restore and alert drills passed (`agents/journal/2026-11-06-install-pigsty.md`, `agents/journal/2026-11-07-restore-test-blinko-copy.md`, `agents/journal/2026-11-07-backup-age-alerts.md`) |
| Blinko | Note-taking app, to test the shared Postgres (`apps/vps/blinko/`). Public domain, behind its own login. Stops after 20 idle minutes (Sablier). | remote VPS, database on `pigsty-1` | running, as a test (`agents/journal/2026-11-07-deploy-blinko.md`) |
| Supabase (self-hosted) | Shared Postgres/auth/storage backend for small apps. | unknown | in docs, not verified |
| ntfy bus | Push-notification service. Backup jobs, deploys, and security alerts post here. | unknown | stable — offsite "is the host itself down?" check still to do |
| Nextcloud AIO | Self-hosted file sync (Dropbox replacement), all-in-one container. Data folder on the TrueNAS share `back` (`imp/back/nextcloud`); nightly Borg backup to BorgWarehouse (`lab/systems/backups.md`). | gpu_docker | down: its automatic update failed (read from the container's log); full restore test still to do |
| Uptime Kuma | Up/down monitoring. One copy ran on the Raspberry Pi until its rebuild (`agents/journal/2026-11-14-rebuild-oob-pi.md`); another runs on the Portainer host. A fresh one on the VPS is planned. | portainer instance | running — verified: Portainer API |
| Sablier | Stops idle apps and starts them on the next request (`agents/plans/sablier-wakeups.md`, `apps/vps/sablier/`). | remote VPS | running; Blinko, pgAdmin and CloudBeaver sleep behind it (`agents/journal/2026-11-07-deploy-sablier.md`) |
| Authentik | Single sign-on for the lab (`apps/vps/authentik/`). Public login; admin interface on a tailnet-only hostname. Mail through Resend. | remote VPS, database on `pigsty-1` | running — verified: health and access checks (`lab/inventory/notes/services.md`); first app sign-in: Langfuse |
| Langfuse | The AI reviewer's trace viewer and evaluation tool (`apps/vps/langfuse/`). Public, sign-in through Authentik only. Stops after 20 idle minutes (Sablier). Event files in a B2 bucket. | remote VPS, database on `pigsty-1` | running — verified: health, sign-in and a probe trace (`lab/inventory/notes/services.md`); no real traces yet |
| pg-proxy | One address on the VPS for the shared Postgres (`apps/vps/pg-proxy/`): 5432 for apps, 5436 for the database UIs. | remote VPS | running — verified: a login as `blinko` through `pg-proxy:5432` reached the primary, and `dbuser_owner` through 5436 (`agents/journal/2026-11-09-deploy-pg-proxy.md`) |
| pgAdmin | Web UI for the shared Postgres (`apps/vps/pgadmin/`). Tailnet only; signs in through Authentik or its own login. | remote VPS | running — verified: 200 over the tailnet, 403 from the public address (`agents/journal/2026-11-09-deploy-db-admin-uis.md`); the Authentik button reaches Authentik's sign-in (`curl`; `agents/journal/2026-11-20-db-ui-sign-in-authentik.md`) |
| CloudBeaver | Web UI for the shared Postgres (`apps/vps/cloudbeaver/`). Tailnet only; signs in once, through Authentik's forward-auth, on its own network. | remote VPS | running — verified: 403 from the public address, setup wizard skipped (`agents/journal/2026-11-09-deploy-db-admin-uis.md`); a request over the tailnet without an Authentik session is sent to Authentik (`curl`; `agents/journal/2026-11-20-db-ui-sign-in-authentik.md`) |
| Dokploy | Deploys every app on the VPS (`lab/systems/vps.md`). `apps/vps/openbao/`, `apps/vps/hermes-webui/`, `apps/vps/blinko/`, `apps/vps/sablier/`, `apps/vps/pg-proxy/`, `apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`, `apps/vps/authentik/` and `apps/vps/langfuse/` are in this repo; the rest are not yet. | remote VPS | running — verified: SSH recon |
| OpenBao | Secret store. See `lab/systems/openbao.md`. | remote VPS | running, unsealed — verified: `/v1/sys/health` 200 (`agents/journal/2026-10-26-install-openbao.md`); Dokploy reads it at deploy time; backup to Garage S3 and restore verified (`agents/journal/2026-10-29-restore-test-openbao.md`) |
| Hermes WebUI (second) | Chat web UI for someone without lab access: own container and volumes; signs in through Authentik or its own password; `apps/vps/hermes-webui/`. | remote VPS | running — WebUI and agent pair updated and re-checked, chat works after it (owner; `agents/journal/2026-11-21-update-hermes-webui.md`); Authentik sign-in reaches Authentik's login (`curl`; `agents/journal/2026-11-20-hermes-webui-sign-in-authentik.md`); backups not set up |
| Immich | Photo and video library. Library on the TrueNAS share `back` (`imp/back/immich`); its Postgres (with VectorChord) and machine learning on local disk, machine learning on the GPU. | gpu_docker | running — verified: SSH |
| Jellyfin | Media server. Media on the TrueNAS share `home` (`Main/home/media`), config and cache on local disk; transcodes on the GPU. | gpu_docker | running — verified: SSH |
| AdGuard Home | DNS ad blocker. Whether any device uses it is not checked. | adguard-docker | running — verified: Portainer API |
| wg-easy | WireGuard server with a web UI. | portainer instance | running — verified: Portainer API; who uses it not checked |
| Homepage, MySpeed | A start page, and a speed-test logger. | gpu_docker | running — verified: SSH |
| Ollama | Local language-model runner, installed on the host, not in Docker. | gpu_docker | enabled as a service — verified: SSH |
| OCI Borgmatic | Planned: run Borg backups on a cheap cloud VM. | — | design only — do not deploy yet |
| Object storage lab | Experiment: S3-compatible storage (Garage/SeaweedFS) across two sites. | — | idea, not built |

When each row was checked: `lab/inventory/notes/services.md`.

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

How each service is backed up: `lab/systems/backups.md`.

## To do

- WUD (What's Up Docker) for container-update notices — replaces Watchtower.
- When monitoring is set up (`agents/decisions/open-questions.md`, Observability):
  scrape Mattermost's metrics. Its Performance Monitoring was turned on in the
  System Console on 2026-10-29 (owner), which serves Prometheus metrics on the
  container's port 8067. Nothing collects them yet.
