# Services — what runs here

This file owns the service list. Other pages link here, never copy this table.
IPs live in `inventory/network.md`; "unknown" in the Host column means no
document says, and the read-only recon pass has not filled it in yet.

| Service | What it is | Host | State |
|---|---|---|---|
| Xen Orchestra | Web UI that manages all VMs: start/stop, snapshots, scheduled backups. | unknown | stable — sends alerts to ntfy |
| TrueNAS VM | Storage OS. Holds file shares and is the backup target for VM images. | `.160` | stable — full clean-import restore still to test |
| Garage (S3) | S3-compatible object store, port 30188. Holds Dokploy backups and, once created, the OpenTofu state bucket. | TrueNAS VM | running — single node, no redundancy |
| BorgWarehouse | Web UI for BorgBackup. Used for app-level backups where a full VM image is not enough (e.g. inside Nextcloud). | TrueNAS VM | stable |
| Portainer CE | Web UI for the homeserver's Docker stacks. Every homeserver app is deployed from here today. | unknown | stable — replacement not decided, Arcane is the likely candidate |
| Nginx Proxy Manager | Reverse proxy: routes public traffic from Cloudflare to the right container by domain. | `.254` | in docs, not verified |
| apt cache | Package cache on port 3142 so local VMs don't re-download packages. | `.254` | in docs, not verified |
| Fail2Ban | Bans brute-force IPs at the firewall by watching logs. | unknown | in docs, not verified |
| Tailscale | Private mesh VPN; the only admin path. | every admin-reachable machine | in docs, not verified |
| Supabase (self-hosted) | Shared Postgres/auth/storage backend for small apps. | unknown | in docs, not verified |
| ntfy bus | Push-notification service. Backup jobs, deploys, and security alerts post here. | unknown | stable — offsite "is the host itself down?" check still to do |
| Nextcloud AIO | Self-hosted file sync (Dropbox replacement), all-in-one container. | unknown | stable — full restore test still to do |
| Uptime Kuma | Up/down monitoring. Named once in the old platform page; nothing else mentions it. | unknown | unknown whether it runs |
| Dokploy | Container manager on the remote VPS. Outside this repo's scope beyond this row. | remote VPS | running |
| OpenBao | Secret store. See `docs/secrets-openbao.md`. | — | planned, not deployed |
| OCI Borgmatic | Planned: run Borg backups on a cheap cloud VM. | — | design only — do not deploy yet |
| Object storage lab | Experiment: S3-compatible storage (Garage/SeaweedFS) across two sites. | — | idea, not built |

How each service is backed up: `ops/backup-restore.md`.

## To do

- WUD (What's Up Docker) for container-update notices — replaces Watchtower.
