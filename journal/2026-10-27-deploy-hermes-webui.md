# 2026-10-27 — deployed the second Hermes WebUI on the VPS

**Who:** the owner, with Claude Code (Opus 5.5) and pi  **Scope:** remote VPS, Dokploy service for `apps/vps/hermes-webui/`  **Mode:** write
**Task:** deploy the second Hermes WebUI (`apps/vps/hermes-webui/`)  **Skill:** `skills/deploy-on-dokploy/` (steps 4–7, differences in the app's `README.md`)

## What changed

- Dokploy Compose service created from this repo (`main`,
  `apps/vps/hermes-webui/compose.yaml`), auto-deploy off, one public domain
  with HTTPS, no admin port. Two named volumes: `hermes-webui-home`,
  `hermes-webui-workspace`.
- Image `ghcr.io/nesquena/hermes-webui:0.52.561`. `0.52.544` was tried first
  and could not install the agent (upstream #8524; the fix, #8544, first ships
  in the 0.52.556+ builds).
- Password not stored in Dokploy: the service environment holds
  `${{vault.openbao.dokploy/hermes-webui:password}}`, read from OpenBao at
  deploy time. The first attempt failed with
  `HashiCorp Vault: failed to read secret at "dokploy/hermes-webui" (status 403)`
  because the provider's KV Mount was left at its `secret` default; setting it
  to `kv` fixed it (the setting, the policy shape and the token's renewal:
  `systems/openbao.md`). This is the first app whose secret comes from OpenBao
  (`plans/vps-foundations.md` step 3).
- Agent v0.22.5 copied from `nousresearch/hermes-agent:v0.22.5` into
  `~/.hermes/hermes-agent` in the home volume — the WebUI image carries no
  agent of its own (`apps/vps/hermes-webui/README.md`, "First deploy").
- `expose: "8787"` added to the compose file (before this branch, in the
  stack's first merge): without it the domain did not route on this Dokploy.
  The WebUI's own image revision is unrelated — this is a Traefik/Dokploy
  behaviour, seen once, version not recorded.
- A custom OpenAI-compatible provider was configured inside the container with
  `docker exec -it -u hermeswebui -e HOME=/home/hermeswebui <container>
  /app/venv/bin/hermes model`, which writes `~/.hermes/config.yaml` and `.env`
  in the volume.

## Snapshot / backup taken

OCI boot-volume backup `ui`, taken by the owner before this deploy (owner,
2026-10-27), and named here as the precondition `skills/deploy-on-dokploy/`
asks for before writing to the VPS. Not queried by the agent — there is no OCI
CLI on this machine — so whether it had finished is unverified here. It is a
boot-volume backup, not a restore test (`systems/backups.md`).

## How it was verified

- Container log: `Downloading cpython-3.14`,
  `Applying hermes-agent's [tool.uv] override-dependencies (4 entries)`,
  `Resolved 106 packages`, `Hermes agent critical imports verified`,
  `listening on http://0.0.0.0:8787`; startup config shows the agent dir
  `[ok]` and a Python 3.14 venv.
- The app answers on its domain over HTTPS, the password login works, and a
  chat request completed (owner, 2026-10-27).
- `docker compose config` with `.env.example` passes, locally and in CI.

## Still open

- Backups: not set up, and no restore tried (`skills/deploy-on-dokploy/` step
  9, `systems/backups.md`).
- Upgrading either image is untested; the agent copy has to be refreshed by
  hand on an agent upgrade.
- Upstream: agent v0.22.5 needs its Pillow override to install; the pinned
  image applies it for us. Rolling back below 0.52.556 reintroduces #8524.
- Dokploy's OpenBao provider token expires unless renewed (`systems/openbao.md`).
- No SSO: the app's own password is the only login
  (`plans/vps-foundations.md` step 4).
