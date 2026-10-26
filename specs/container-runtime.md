---
id: container-runtime
type: module-design
title: container-runtime — Portainer, probably Arcane
status: draft
parent: arch-homelab
---

# container-runtime

**Responsibility.** Run the homeserver's application stacks and keep their
definitions in a reviewable form.

**Owns.** The homeserver Docker host, and the app definitions once they move
into this repo. Today it owns nothing in git: stacks exist only inside Portainer.

**Boundary.** It holds no secret values (`secrets-openbao`) and creates no VMs
(`iac-provisioning`). It does not cover the remote VPS, which stays on Dokploy
and is outside this repo's scope.

## Shape today

Portainer CE on the Docker host. Stacks were created in its UI, so the Compose
files and `.env` files live in Portainer's database rather than here. Some of
those services have not been touched in three years.

## Target (probably)

- One directory per app in git: `compose.yaml` plus references, using `${VAR}`
  and `file:` secrets, never values.
- A manager that deploys from that git directory, so the repo — not the UI — is
  the source of truth.
- Migration one stack at a time; the old copy keeps running until the new one is
  healthy.

## Unconfirmed — research needed

- **Manager:** Arcane is the likely candidate, Komodo the alternative if
  per-project git is outgrown. Nothing chosen, nothing tested.
- **Native vault support:** whether Arcane reads OpenBao itself. The current
  assumption is that it does not, which is why a sidecar is assumed.
- **Scope:** whether every stack is worth migrating. Some are three years old and
  may be retired instead.
