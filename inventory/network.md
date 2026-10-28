---
type: inventory
status: "documented, unverified"
verified: "no (from docs, not verified against router)"
hosts:
  - "[Docker + proxy host](hosts.md)"
  - "[TrueNAS VM](hosts.md)"
related:
  - "[Hosts](hosts.md)"
  - "[Services](services.md)"
tags:
  - inventory
  - network
  - traffic
  - subnets
---

# Network

This file owns every IP address. Hosts are named as in `hosts.md`; what runs
on each is in `services.md`.

**Source:** from the docs, not verified against the router.

Private subnet `10.22.33.0/24`.

| IP | Host |
|---|---|
| `.1` | router / gateway |
| `.254` | Docker + proxy host |
| `.160` | TrueNAS VM |

## How traffic flows

```mermaid
flowchart TD
    subgraph AdminAccess["Admin Access (Zero-Trust)"]
        Admin["Admin (owner, agents)"] -->|Encrypted Mesh| Tailscale["Tailscale VPN"]
        Tailscale -->|Direct secure admin access| Services["Admin Services\n(No public ports / No public SSH)"]
    end

    subgraph PublicAccess["Public Web Traffic"]
        Client["Public Web Client"] -->|HTTPS| Cloudflare["Cloudflare\n(Filter / DDOS / Blocks junk)"]
        Cloudflare --> NPM["Nginx Proxy Manager\n(Routes by domain)"]
        NPM --> Containers["Application Containers"]
        Fail2Ban["Fail2Ban\n(Watches logs & bans brute-force)"] -.->|Firewall block| NPM
    end

    subgraph AppBackends["Backend Services"]
        Containers -->|Default shared backend| Supabase["Supabase\n(Postgres / Auth / Storage)"]
        Containers -->|Dedicated storage| LocalDB["App-local Data / Files"]
    end
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
