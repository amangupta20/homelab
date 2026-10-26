# The remote VPS stays on Dokploy and is not managed from this repo

Decided: 2026-10-26. Status: in force.

## Why

The public-facing parts run on a small remote VPS under Dokploy. The decision
was recorded (in the former container-runtime spec) without a reason —
**reason still to be written by the owner.** This repo covers the homeserver.

## Cost / what this rules out

- The VPS appears only as one row in `inventory/services.md` and in the
  secret-delivery notes in `docs/secrets-openbao.md`.
- Its backups (to Garage) depend on the homeserver, so a Garage outage
  affects it.

## Where it lives

`inventory/services.md` (Dokploy row), `docs/secrets-openbao.md`.
