# 2026-11-23 — Router DNS through the Pi; the Pi becomes cluster primary

**Who:** Claude Code, at the owner's request. **Scope:** Home router, `oob-1`.
**Mode:** write. **Task:** B4b of `agents/plans/home-overhaul.md`. **Skill:** none.

## What changed

- Router (by `uci`, owner's interim choice): DHCP option 6 hands out the Pi, then
  the router; the router's dnsmasq forwards to the Pi first and the ISP router
  second (`strictorder`, `noresolv`). Details: `lab/systems/notes/router.md`.
- `oob-1`, by `ansible/oob.yml`: Technitium's query ACL also allows Tailscale's
  ranges (for the VPS node); the firewall opens 53443 to the router's address; the
  Pi initialised the cluster `dns.home.arpa` as primary and the `home` zone joined
  the cluster's catalog.
- OpenBao: `kv/dokploy/technitium` for the VPS node (its tailnet address, a copy
  of the admin password).

## Snapshot / backup taken

Router: `/etc/config/dhcp.bak-2026-11-23`. The Pi is rebuilt from this repo.

## How it was verified

- Cluster init and join rehearsed first on two throwaway 15.6.2 containers on
  agent-1: settings, allowed list and catalog zones reached the secondary, which
  answered a `home` name; the HTTP API kept working after HTTPS came on.
- Pi: the playbook applied, a second run `changed=0`; the cluster API lists
  `oob-1.dns.home.arpa` as primary, and the `home` zone shows the catalog; `dig`
  still blocks and answers.
- Router: `dig @10.22.33.1` blocked a tracker name and answered others and a
  `home` name; with the Pi's container stopped, queries hung about 30 seconds,
  then answered through the ISP; with it back, blocking returned at once.

## Still open

The VPS node (deploy, join), then DHCP and the tailnet's nameservers (B4b).
