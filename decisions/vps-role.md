# The VPS runs what must stay up, what others use, and overflow

Decided: 2026-10-26. Status: in force.

## Why

The lab is split on purpose between the physical homelab and a remote VPS
deployed with Dokploy. The VPS gets:

- **What must stay up 24/7, no matter what** happens at home (power, ISP,
  hardware, a migration gone wrong).
- **What other people use** — apps built for someone else or shared with
  them, so their access does not depend on the home network.
- **Overflow** — things that need more resources than home has free.
- **Quick deploys** — sometimes it is simply the faster place to put something.

Everything else runs at home. The two sides reach each other over Tailscale.

## Cost / what this rules out

- The VPS is the public-facing side: its docs are where a real domain or
  public IP is most likely to slip into this public repo
  (`repo/secret-scanning.md`).
- Dokploy is the deployment tool for the VPS only; the homeserver's container
  manager is a separate, still open question.
- Whether an app goes home or VPS is decided per app against the list above,
  and recorded in its `inventory/services.md` row.

## Where it lives

`systems/vps.md`, `inventory/hosts.md`, `inventory/services.md`, `apps/vps/`.
