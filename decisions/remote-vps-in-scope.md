# The remote VPS is part of this repo and will be migrated into it

Decided: 2026-10-26. Status: in force. Replaces an earlier note that kept the
VPS out of scope.

## Why

The VPS runs the public-facing parts of the lab under Dokploy. Leaving it out
would make this repo a record of half the lab, and its stacks would stay
configured only inside Dokploy's UI — the same problem the homeserver has with
Portainer.

## Cost / what this rules out

- Nothing about the VPS is documented yet beyond one row in
  `inventory/services.md`.
- How its definitions sit in the repo (own folder or alongside the homeserver
  apps) and how Dokploy deploys from this repo are both undecided
  (`open-questions.md`).
- The VPS is the public-facing part, so its docs are where a real domain or
  public IP is most likely to slip into this public repo. The leak rules in
  `repo/secret-scanning.md` need to cover it before its docs are written.

## Where it lives

`inventory/services.md` (Dokploy row), `systems/openbao.md` (how Dokploy
reads secrets).
