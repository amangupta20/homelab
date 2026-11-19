# The VPS stays outside OpenTofu

Decided: 2026-10-26 by the owner, in a working session; written up by an
agent. Status: in force.

## Why

The VPS is an Oracle Cloud free-tier Ampere instance that has run for months
(`systems/vps.md`). The owner has no reason to rebuild it, and importing it
into OpenTofu state would buy nothing: OpenTofu's value here is recreating a
machine from code, and this machine is not going to be recreated. What runs on
it is what changes, and that is moving into `apps/vps/` as Compose files that
Dokploy deploys (`plans/vps-foundations.md`, step 5).

This answers step 1 of `plans/vps-foundations.md`.

## Cost / what this rules out

- If the VPS is lost, it is rebuilt by hand: create the instance, install
  Tailscale and Dokploy, restore Dokploy and the apps from backups. That
  procedure is not written yet and is only as good as the restore tests in
  `systems/backups.md`.
- "Reproducible from code" (`README.md`) covers the VPS's apps, not the VPS
  itself.
- Revisit if the free tier ends or the instance has to move.

## Where it lives

`systems/vps.md`, `plans/vps-foundations.md`.
