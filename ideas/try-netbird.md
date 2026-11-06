---
type: idea
status: "researched"
verified: "no (research only; NetBird was not run)"
tags:
  - idea
  - networking
  - tailscale
---

# Try NetBird as an alternative to Tailscale

**Status:** researched
**In one line:** NetBird is a mesh VPN built on WireGuard, with its own control server,
relay and web UI, all of which can be self-hosted.
**Why try it:** the owner likes the look of it, and it would teach what running a whole
mesh VPN involves. It offers a web UI for access rules and no vendor account.
**Needs first:** the home lab back up, and Pangolin running, so the spare capacity is
known. Tailscale stays the working setup while this is tried.

## Design sketch

Try it on the side, and do not migrate as part of the trial:

1. Use NetBird's hosted version, or a small throwaway VM, with one laptop and a test
   node.
2. Leave `10.22.33.0/24` on Tailscale. Two systems routing one subnet would conflict.
3. Test the phone client, subnet access, access rules, a restart of the control server,
   and a restore from backup.
4. Only if it is still preferred after a few weeks, move one node at a time, and keep
   Tailscale installed as the way back in.

Self-hosting needs a public domain, TCP 80 and 443, UDP 3478, Docker with Compose, and
at least 1 CPU and 2 GB of memory, with relay and STUN in the combined server (NetBird's
quickstart, read 2026-11-06). arm64 was not covered on that page.

## Risks and costs

- **Circular dependency:** OpenBao and admin access run over the mesh VPN. A control
  server hosted on those same machines is needed to repair itself, so a separate way in
  must exist first.
- **Capacity:** on the Oracle account that holds `pigsty-1` it would compete with
  Pangolin for the remaining free allowance.
- **Upkeep:** another always-on service with its own updates, backups and restore test
  (`systems/backups.md`).
- **Licence:** the server components are AGPLv3. One comparison says production
  self-hosting needs a commercial tier, while the quickstart does not mention one.
  Unverified; check before relying on it.
- **Sign-in:** tying it to the lab's SSO would make logging in depend on SSO being up.

## Promote when

The owner wants to, and either: Tailscale's free plan stops fitting (6 users, 50 tagged
devices, as of 2026-11-06), a self-hosted UI for access rules or owning the whole stack
becomes a real goal, or relays become a problem that NetBird's built-in one would solve.

If the goal is only leaving Tailscale's control server, compare Headscale first: it keeps
the same clients, but has no web UI of its own.

## Sources

Researched 2026-11-06. Nothing was installed.

- NetBird self-hosting quickstart: <https://docs.netbird.io/selfhosted/selfhosted-quickstart>
- Comparison with licences and prices, October 2026 (second-hand):
  <https://wz-it.com/en/blog/mesh-vpn-comparison-2026-overview/>
- Tailscale pricing: <https://tailscale.com/pricing>
- GitHub: <https://github.com/netbirdio/netbird>, <https://github.com/juanfont/headscale>
