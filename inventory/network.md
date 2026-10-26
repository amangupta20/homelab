# Network & hosts

Private subnet `10.22.33.0/24`.

| IP | What |
|---|---|
| `.1` | router / gateway |
| `.254` | Docker + reverse-proxy host. Also runs apt cache on port 3142 so local VMs don't re-download packages. Clients set it in `/etc/apt/apt.conf.d/00proxy`. |
| `.160` | TrueNAS storage + BorgWarehouse. Also runs Garage (S3-compatible object store) on port 30188; it holds the OpenTofu state bucket. |

## How traffic flows

- Admin (me, agents): only over Tailscale, a private mesh VPN between my
  devices. Nothing admin-facing listens on the public internet. No public SSH.
- Public web: Cloudflare (blocks junk) -> Nginx Proxy Manager (routes by
  domain) -> the right container. Fail2Ban watches logs and bans brute-force
  IPs at the firewall.
- Default app backend: self-hosted Supabase (shared Postgres/auth/storage for
  small apps), unless the app needs its database close to its files (then the
  metadata moves next to it).

Open item: no external "is my whole host down?" monitor yet.
