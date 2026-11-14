---
type: inventory
status: "documented, partially verified"
verified: "partially (Remote VPS verified 2026-10-26 over SSH; pigsty-1 verified 2026-11-06 over SSH; XCP-ng host hardware verified 2026-11-13 at the console; Home router verified 2026-11-13 over SSH; oob-1 verified 2026-11-14 over SSH; the home VMs and TrueNAS verified 2026-11-14 through the Xen Orchestra, TrueNAS and Portainer APIs; other hosts from docs)"
tags:
  - inventory
  - hosts
  - infrastructure
---

# Hosts — every machine

This file owns the host list. IPs live in `network.md`; services in
`services.md`.

**Source:** every row is from the docs and is not verified against the live
lab, unless its State says `verified: …`. The read-only recon pass fills in
names, sizes and the unknowns.

| Host | Kind | Runs on | Role | OS | State |
|---|---|---|---|---|---|
| XCP-ng host | bare-metal server (Gigabyte B450M DS3H, AMD Ryzen 5 1600, 40 GB RAM; `systems/xcp-ng.md`, "Hardware") | — | hypervisor for every VM | XCP-ng | hardware verified: 2026-11-13 by the owner at the console; role and OS in docs, not verified |
| TrueNAS VM | VM `aaTruenas-core`, 4 CPU / 8 GB; data disks are the two physical disks passed through whole (`systems/truenas.md`) | XCP-ng host | storage; Garage and BorgWarehouse as TrueNAS apps | TrueNAS 25.10.4 | running — verified: TrueNAS API 2026-11-14 |
| Docker + proxy host | unknown | unknown | Docker stacks, Nginx Proxy Manager, apt cache | unknown | in docs, not verified |
| Xen Orchestra | VM `xo-ce`, 2 CPU / 4 GB, 30 GB disk | XCP-ng host | manages VMs and backups (Xen Orchestra built from source) | Debian 13 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14 |
| Remote VPS | VPS (Oracle Cloud, Ampere ARM64, 4 CPU / 23 GiB) | Oracle Cloud | always-on, shared and overflow apps via Dokploy; OpenBao and SSO planned (`systems/vps.md`) | Ubuntu 24.04.4 | running — verified: recon 2026-10-26 over SSH |
| pigsty-1 | VPS (Oracle Cloud, Ampere ARM64, 3 CPU / 18 GB, 150 GB disk, separate account from the Remote VPS) | Oracle Cloud | the second VPS: Pigsty node, installed 2026-11-06, no apps yet (`plans/shared-postgres.md`, `iac/oci/`) | Ubuntu 24.04.5 | running — verified: 2026-11-06 over SSH |
| Home router | router (Jio AirFiber indoor unit JIDU6411, 4 cores / 512 MB) | — | gateway, DHCP, DNS and Wi-Fi for the home subnet (`systems/router.md`) | OpenWrt (community snapshot build) | running — verified: 2026-11-13 over SSH |
| oob-1 | Raspberry Pi 3 Model B Plus, 1 GB RAM | — | out-of-band way into the home LAN: subnet router on a second Tailscale account (`systems/oob.md`) | Raspberry Pi OS Lite 64-bit (Debian 13) | running — verified: 2026-11-14 over SSH |
| gpu_docker | VM, 8 CPU / 6 GB, 200 GB disk, NVIDIA GTX 1050 Ti passed through; hostname `dockergpu` | XCP-ng host | Docker host for the GPU apps and most home apps: Nextcloud AIO, Immich, Jellyfin | Ubuntu 24.04.4 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14 |
| portainer instance | VM, 3 CPU / 1.5 GB, 40 GB disk | XCP-ng host | Portainer server; Uptime Kuma, wg-easy | Ubuntu 24.04.4 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14, Portainer API |
| NPM-set | VM, 2 CPU / 0.7 GB, 40 GB disk | XCP-ng host | Nginx Proxy Manager, Fail2Ban | Debian 12 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14, Portainer API |
| adguard-docker | VM, 2 CPU / 0.6 GB, 20 GB disk | XCP-ng host | AdGuard Home | Debian 13 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14, Portainer API |
| apt-cache | VM, 2 CPU / 1 GB, 40 GB disk | XCP-ng host | apt-cacher-ng on port 3142; no Docker | Debian 13 | running — verified: Xen Orchestra's REST API and SSH, 2026-11-14 |
| Stopped VMs | `Dokploy` (5 CPU / 5 GB), `Minecraft` (6 / 10 GB), `arkserver` (6 / 24 GB), `zorin os test` (6 / 6 GB), two `XOA` (2 / 2 GB each) | XCP-ng host | not running; whether to keep each is open (`plans/home-overhaul.md`) | various | halted — verified: Xen Orchestra's REST API 2026-11-14 |
| Agent VM | VM `agent-1` (proposed 4 CPU / 8 GB) | XCP-ng host | runs coding and maintenance agents (Claude Code, Codex, opencode, Hermes, pi/omp), mostly as Orca workers (`plans/home-overhaul.md`, B0) | — | planned |
