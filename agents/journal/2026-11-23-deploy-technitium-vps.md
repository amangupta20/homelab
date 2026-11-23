# 2026-11-23 — Deployed the VPS Technitium node and joined the cluster

**Who:** Claude Code, at the owner's request. **Scope:** remote VPS (Dokploy),
`oob-1`, Home router. **Mode:** write. **Task:** B4b of `agents/plans/home-overhaul.md`.
**Skill:** `agents/skills/deploy-on-dokploy/` (by Dokploy's REST API, not the UI).

## What changed

- Dokploy: project and Compose service `technitium` from `main`
  (`apps/vps/technitium/`), env from OpenBao; the OpenBao provider's assignments lost
  one entry for a deleted project and gained this one.
- The owner added a tailnet grant: `tag:dokploy` to the Pi on 53443 and 53.
- The VPS node joined the cluster; `ansible/oob.yml` added the router to the catalog's
  zone-transfer list. Details: `apps/vps/technitium/NOTES.md`.
- Router: DHCP option 6 and dnsmasq's servers are the Pi, then the VPS
  (`lab/systems/notes/router.md`).

## Snapshot / backup taken

None of the VPS: a new service. Router: `/etc/config/dhcp.bak-2026-11-23b`.

## How it was verified

- Container `healthy`, ports on the tailnet address only; the public address does
  not answer DNS. Over the tailnet it blocks and answers like the Pi, holds 573,538
  block-list entries and the `home` zone (authoritative answer).
- Cluster: the VPS sees the Pi `Connected`, no heartbeat failures after the fix.
- The tailnet policy: the VPS reaches the Pi on 53443 (200), not on 22 or 5380.
- Pi stopped: the router answered through the VPS in about 3 s, still blocking.

## Still open

The Pi lists the VPS as `Unreachable` (its own Tailscale drops the replies); the
tailnet's nameservers are still to be set in the admin console.
