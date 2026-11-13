---
type: inventory
status: "documented, partially verified"
verified: "partially (Remote VPS verified 2026-10-26 over SSH; pigsty-1 verified 2026-11-06 over SSH; XCP-ng host hardware verified 2026-11-13 at the console; Home router verified 2026-11-13 over SSH; other hosts from docs)"
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
| TrueNAS VM | VM | XCP-ng host | storage, VM backup target, Garage, BorgWarehouse | TrueNAS | in docs, not verified |
| Docker + proxy host | unknown | unknown | Docker stacks, Nginx Proxy Manager, apt cache | unknown | in docs, not verified |
| Xen Orchestra | unknown | unknown | manages VMs and backups | unknown | in docs, not verified |
| Remote VPS | VPS (Oracle Cloud, Ampere ARM64, 4 CPU / 23 GiB) | Oracle Cloud | always-on, shared and overflow apps via Dokploy; OpenBao and SSO planned (`systems/vps.md`) | Ubuntu 24.04.4 | running — verified: recon 2026-10-26 over SSH |
| pigsty-1 | VPS (Oracle Cloud, Ampere ARM64, 3 CPU / 18 GB, 150 GB disk, separate account from the Remote VPS) | Oracle Cloud | the second VPS: Pigsty node, installed 2026-11-06, no apps yet (`plans/shared-postgres.md`, `iac/oci/`) | Ubuntu 24.04.5 | running — verified: 2026-11-06 over SSH |
| Home router | router (Jio AirFiber indoor unit JIDU6411, 4 cores / 512 MB) | — | gateway, DHCP, DNS and Wi-Fi for the home subnet (`systems/router.md`) | OpenWrt (community snapshot build) | running — verified: 2026-11-13 over SSH |
| Agent VM | VM | XCP-ng host | runs the maintenance agent | — | planned |
