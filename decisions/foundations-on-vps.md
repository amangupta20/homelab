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

## If OpenBao ever has to face the internet

Reaffirmed by the owner on 2026-10-26: tailnet-only for now. Encryption at
rest and the unseal pieces protect the data on disk, not the running API —
once unsealed, anyone who reaches it can try passwords or a pre-login bug
against every secret at once.

What would justify a public door: a consumer that can be neither on the
tailnet nor on the VPS itself — a CI runner such as GitHub Actions, a server
someone else runs, a device that cannot run Tailscale. Consumers on the VPS
reach OpenBao over Docker's network, and containers on a tailnet host go out
through that host, so neither is a reason.

Conditions if it happens, decided again at that time:

- Open the narrowest door that serves that consumer — client certificates
  (mTLS) or a Cloudflare Access service token in front, so a request without
  them never reaches OpenBao — rather than OpenBao itself on a public port.
- Login lockout after failed attempts, a second factor on human logins, the
  root token revoked, the audit log on with alerts to ntfy, and updates
  applied promptly.
- This decision is updated first, with the consumer that needed it.

## Where it lives

`systems/vps.md`, `systems/openbao.md`, `plans/vps-foundations.md`.
