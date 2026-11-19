---
type: inventory
tags:
  - inventory
  - network
  - traffic
  - subnets
---

# Network

This file owns every IP address. Hosts are named as in `hosts.md`; what runs
on each is in `services.md`.

**Source:** from the docs and not verified, unless a row's State says
`verified: …`.

Private subnet `10.22.33.0/24`, served by the Home router
(`systems/router.md`).

| IP | Host | State |
|---|---|---|
| `.1` | Home router: gateway, DHCP, DNS | verified: `uci show network` over SSH 2026-11-13 |
| `.10`–`.54` | DHCP pool, 12-hour leases. Moved from `.100`–`.249` on 2026-11-16 (owner's request), so addresses above `.100` are free for fixed addresses set by each machine; it stops at `.54` to stay clear of `.55`, `.99` and `.100`, which are set on their machines. The router has no DHCP reservations | verified: `uci show dhcp` and the generated `dhcp-range` over SSH 2026-11-16 |
| `.252` | oob-1, static, outside the DHCP pool (`systems/oob.md`) | verified: `ip -br a` over SSH 2026-11-14 |
| `.254` | apt-cache (apt-cacher-ng, no Docker) | verified: SSH 2026-11-14 |
| `.55` | portainer instance | verified: SSH and Portainer API 2026-11-14 |
| `.99` | NPM-set | verified: SSH and Portainer API 2026-11-14 |
| `.100` | Xen Orchestra (`xo-ce`) | verified: its REST API answered 2026-11-14 |
| `.137` | cache VM `cache-1` (`agents/plans/package-and-image-cache.md`); set on the VM by OpenTofu and cloud-init | verified: over SSH `eth0` at `.137/24`, and Xen Orchestra's agent reported it, 2026-11-16 (`agents/journal/2026-11-16-build-cache-1.md`) |
| `.138` | home reverse proxy `proxy-1` (`apps/homeserver/traefik/`); set on the VM by OpenTofu and cloud-init. The public record `*.home.<zone>` points here | verified: over SSH `eth0` at `.138/24`, and the router's dnsmasq answering `cache.home.<zone>` with it, 2026-11-18 (`agents/journal/2026-11-18-build-proxy-1-traefik.md`) |
| `.123` | gpu_docker | verified: SSH 2026-11-14 |
| `.160` | TrueNAS VM | verified: TrueNAS API 2026-11-14 |
| `.253` | adguard-docker | verified: SSH and Portainer API 2026-11-14 |

Upstream of the Home router is the ISP router's own private network,
`192.168.1.0/24`: the Home router takes an address there by DHCP and the ISP
router is its gateway (`uci show network`, `ip route`, 2026-11-13).

Oracle Cloud network for `iac/oci/`: `10.40.0.0/16`, subnet `10.40.1.0/24`
(`iac/oci/network.tf`, applied 2026-11-06). Machines there are reached over
Tailscale; their public addresses are not recorded in this repo.

## How traffic flows

```mermaid
flowchart LR
    Admin["Admin: owner and agents"] -->|Tailscale only| AdminUI["Admin interfaces<br/>no public SSH"]
    Visitor["Public visitor"] --> CF["Cloudflare<br/>blocks junk"]
    CF --> NPM["Nginx Proxy Manager<br/>routes by domain"]
    NPM --> Apps["App containers"]
    Apps -->|default| Supabase["Self-hosted Supabase"]
    Apps -->|data next to files| Local["App's own database"]
    F2B["Fail2Ban<br/>watches logs"] -.->|bans IPs at the firewall| NPM
```

- Admin (me, agents): only over Tailscale, a private mesh VPN between my
  devices. Nothing admin-facing listens on the public internet. No public SSH.
- Public web: Cloudflare (blocks junk) -> Nginx Proxy Manager (routes by
  domain) -> the right container. Fail2Ban watches logs and bans brute-force
  IPs at the firewall.
- Default app backend: self-hosted Supabase (shared Postgres/auth/storage for
  small apps), unless the app needs its database close to its files (then the
  metadata moves next to it).

Open item: no external "is my whole host down?" monitor yet.
