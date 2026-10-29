---
type: plan
status: "in progress (steps 0-2 completed, step 3 partially; SSO open)"
verified: "partially (steps 0-3 verified on live VPS 2026-10-26/27; step 2 restore tested on workstation 2026-10-29)"
hosts:
  - Remote VPS
tags:
  - plan
  - vps
  - openbao
  - sso
---

# VPS foundations

**Status:** steps 0–2 completed; step 3 partially completed (Dokploy reads
OpenBao and token renewal automated; OpenTofu half open); step 4 (SSO) is open.
**Goal:** OpenBao and SSO running on the VPS with tested backups, so every app
after them is deployed once with secrets and sign-in already wired.
**Done when:** OpenBao and SSO each have a restore test in `journal/`, and the
first app deployed with `skills/deploy-on-dokploy/` reads its secrets from
OpenBao and signs in through SSO.

Why this order and why on the VPS: `decisions/foundations-on-vps.md`.

## Steps

0. **Document the VPS as it is**, read-only: provider and size, OS, Dokploy
   version, what already runs there, how public traffic enters (Dokploy's own
   proxy or something else), where its backups go. Fill `systems/vps.md` and
   the inventory rows. — gate: `systems/vps.md` has no "not documented yet"
   left in "How it works".
1. **Decide how OpenTofu manages the VPS.** Depends on the provider having an
   OpenTofu provider, and on whether the existing VPS is imported into state or
   rebuilt from code. — gate: a decision file in `decisions/`. Done
   2026-10-26: it doesn't (`decisions/vps-outside-opentofu.md`).
2. **OpenBao on the VPS.** Before installing: a VPS snapshot from the
   provider, or a verified backup of every Dokploy app's data, named in the
   journal entry. Then: storage backend chosen; listener on the Tailscale
   address only, TLS on; initialised with keys kept offline; root token
   deleted; backup to Garage at home; one restore tested
   (`systems/openbao.md`). — gate: restore test in `journal/`. Completed
   2026-10-29 (`journal/2026-10-29-restore-test-openbao.md`): scheduled daily
   Raft snapshot via Dokploy task `openbao-raft-snapshot` to Garage S3, restore
   verified on throwaway podman instance.
3. **Wire secrets into deploys.** Before changing Dokploy's settings: a
   verified Dokploy backup, or the step-2 snapshot if nothing changed since,
   named in the journal entry. Then Dokploy reads OpenBao, and checkouts read
   it for OpenTofu (`iac/vault.tf.example`). — gate: one throwaway app on
   Dokploy reads a test secret from OpenBao. Satisfied 2026-10-27 by a real app
   instead of a throwaway: `apps/vps/hermes-webui/` reads its password from
   `kv/dokploy/hermes-webui` (gotchas in `systems/openbao.md`). The step's
   required backup is the boot-volume backup `ui`, named in that journal entry;
   whether it had finished was not checked, so the "verified" half of the
   precondition stays open. Dokploy's OpenBao provider token renewal is automated
   daily by the `openbao-raft-snapshot` scheduled task. Still open: the OpenTofu half.
4. **SSO.** Choose one (`decisions/open-questions.md`, Foundations), deploy it
   with `skills/deploy-on-dokploy/`, public login, tailnet-only admin, backup
   tested. — gate: the throwaway app from step 3 signs in through it.
5. **Apps.** From here, every VPS app goes through
   `skills/deploy-on-dokploy/` with OpenBao and SSO from the start. Apps
   already on Dokploy move into `apps/vps/` one at a time.

## Follow-ups: apps deployed before the foundations

- `apps/vps/hermes-webui/` — deployed 2026-10-27 while these foundations were
  unfinished (owner). Its password does come from OpenBao through Dokploy's
  provider — the thing step 3 was for — but its own password is still the only
  login: no SSO, and it is public. Revisit after step 4: put it behind SSO, or
  move it to tailnet-only.

## Links

`systems/vps.md`, `systems/openbao.md`, `decisions/vps-role.md`,
`decisions/foundations-on-vps.md`, `plans/migration.md` (the homelab side).
