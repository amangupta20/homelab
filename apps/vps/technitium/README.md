# Technitium on the VPS: the DNS fallback

The second node of the home DNS cluster: Technitium DNS Server as the fallback
for the Raspberry Pi (`apps/homeserver/technitium/`), and the resolver that keeps
the tailnet's DNS working while home is down. Step B4b of
`agents/plans/home-overhaul.md`, which holds the design.

**Status:** see `lab/inventory/services.md`.

- **Where:** remote VPS, deployed by Dokploy from `compose.yaml` here.
- **Address:** DNS (53), the web console (5380) and the cluster's HTTPS API
  (53443) on the VPS's tailnet address only; nothing on a public address.
- **Settings:** none of its own. It joins the cluster as a secondary node, and
  the Pi's blocklists, upstreams, query ACL, allowlist, users and the `home`
  zone sync from there (`ansible/oob.yml` sets them on the Pi). Change them on
  the Pi, not here.
- **Sign-in:** the console's `admin` login, the same password as the Pi's once
  joined (OpenBao `kv/homelab/technitium`). Authentik is not set up for it.
- **Secrets:** `kv/dokploy/technitium` (`.env.example` lists the fields).
- **Data and backups:** a named volume; not backed up, because everything in it
  comes back from the Pi when the node rejoins the cluster (`NOTES.md`, "Rebuild").

The one-time cluster join, what this was derived from and how it was tested:
`NOTES.md`.
