# Services — what runs here

This file owns the service list. Other pages link here, never copy this table.

| Service | What it is | State |
|---|---|---|
| TrueNAS VM | Storage OS. Holds file shares and is the backup target for VM images. | stable — full clean-import restore still to test |
| Xen Orchestra | Web UI that manages all VMs: start/stop, snapshots, scheduled backups. | stable — sends alerts to ntfy |
| BorgWarehouse | Web UI for BorgBackup. Used for app-level backups where a full VM image is not enough (e.g. inside Nextcloud). | stable, runs on TrueNAS |
| ntfy bus | Push-notification service. Backup jobs, deploys, and security alerts post here. | stable — offsite "is the host itself down?" check still to do |
| Nextcloud AIO | Self-hosted file sync (Dropbox replacement), all-in-one container. | stable — full restore test still to do |
| OCI Borgmatic | Planned: run Borg backups on a cheap cloud VM. | design only — do not deploy yet |
| Object storage lab | Experiment: S3-compatible storage (Garage/SeaweedFS) across two sites. | idea, not built |
| Base-snapshot rule | Lesson learned, see platforms page. | never delete a base snapshot by hand |

## Backup strategy in one paragraph

Plain VMs are protected by Xen Orchestra image backups (snapshot + delta)
sent to TrueNAS, then copied offsite. Apps with internal state (Nextcloud)
get an extra backup from inside the app (Borg). No per-VM Borg agent for
plain VMs — image backups cover them.

## To do

- WUD (What's Up Docker) for container-update notices — replaces Watchtower.
