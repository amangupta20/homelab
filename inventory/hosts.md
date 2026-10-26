# Hosts — every machine

This file owns the host list. IPs live in `network.md`; services in
`services.md`. Everything here is from the docs, not verified — the read-only
recon pass fills in names, sizes and the unknowns.

| Host | Kind | Runs on | Role | OS | State |
|---|---|---|---|---|---|
| XCP-ng host | bare-metal server | — | hypervisor for every VM | XCP-ng | in docs, not verified |
| TrueNAS VM | VM | XCP-ng host | storage, VM backup target, Garage, BorgWarehouse | TrueNAS | in docs, not verified |
| Docker + proxy host (`.254`) | unknown | unknown | Docker stacks, Nginx Proxy Manager, apt cache | unknown | in docs, not verified |
| Xen Orchestra | unknown | unknown | manages VMs and backups | unknown | in docs, not verified |
| Remote VPS | VPS | external provider | Dokploy, public-facing apps | unknown | in docs, not verified |
| Agent VM | VM | XCP-ng host | runs the maintenance agent | — | planned |
