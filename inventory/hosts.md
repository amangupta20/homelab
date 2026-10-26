# Hosts — every machine

This file owns the host list. IPs live in `network.md`; services in
`services.md`.

**Source:** every row is from the docs and is not verified against the live
lab, unless its State says `verified: …`. The read-only recon pass fills in
names, sizes and the unknowns.

| Host | Kind | Runs on | Role | OS | State |
|---|---|---|---|---|---|
| XCP-ng host | bare-metal server | — | hypervisor for every VM | XCP-ng | in docs, not verified |
| TrueNAS VM | VM | XCP-ng host | storage, VM backup target, Garage, BorgWarehouse | TrueNAS | in docs, not verified |
| Docker + proxy host | unknown | unknown | Docker stacks, Nginx Proxy Manager, apt cache | unknown | in docs, not verified |
| Xen Orchestra | unknown | unknown | manages VMs and backups | unknown | in docs, not verified |
| Remote VPS | VPS | external provider | always-on, shared and overflow apps via Dokploy; OpenBao and SSO (`systems/vps.md`) | unknown | joined to the tailnet (owner, unverified) |
| Agent VM | VM | XCP-ng host | runs the maintenance agent | — | planned |
