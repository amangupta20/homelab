# OpenBao and SSO run on the VPS, reachable over Tailscale

Decided: 2026-10-26. Status: in force.

## Why

Both sides of the lab depend on secrets and sign-in, so the foundations go
where they stay up when home is down: the VPS (`decisions/vps-role.md`). The
homelab and the VPS are both on the tailnet, so anything at home can reach
them without a public port. Deploying them first means every later app is
deployed once, with its secrets and sign-in already wired, instead of
deployed, then patched for OpenBao, then patched again for SSO.

## Cost / what this rules out

- **OpenBao listens on the VPS's Tailscale address only**, never a public
  port: it holds every secret at once (`systems/openbao.md`). A compromise of
  the VPS itself would still expose it, which is the price of putting it on the
  always-on side; its backup lives at home.
- **SSO has to be public** for the people who use the shared apps; its admin
  side stays tailnet-only.
- If the VPS or the tailnet is down, home services that read secrets at
  deploy time cannot be redeployed until it is back. Running services keep
  working.
- Which SSO is open (`decisions/open-questions.md`).

## Where it lives

`systems/vps.md`, `systems/openbao.md`, `plans/vps-foundations.md`.
