# Second Hermes WebUI on the VPS

A second Hermes WebUI on the VPS for someone without lab access — a plain chat
page over a public domain, no Tailscale or SSH needed. The folder name is the
same as the upstream project; which Dokploy project it is and who uses it live
in Dokploy, not in this public repo.

**Status:** defined, not deployed. First deploy follows
`skills/deploy-on-dokploy/`; the Dokploy steps there are still UNTESTED
against the running instance.

## Derived from

Upstream base for later modifications (re-check these when upgrading):

| Source | Version read | What was taken |
|---|---|---|
| nesquena/hermes-webui `docker-compose.yml` (single container) | 2026-10-27 | whole shape: one container, agent in-process, `HERMES_WEBUI_*` env names |
| nesquena/hermes-webui `docs/docker.md` | 2026-10-27 | tag channels (`:latest` stable), the release-pair rule (WebUI + agent upgrade together as one image), no mixed pinning |
| Hermes Agent docs, Profiles page | 2026-10-27 | profiles as the isolation unit; the dashboard's isolated single-profile posture is a different server, not this one |
| This repo's `skills/deploy-on-dokploy/` | 2026-10-27 | file layout, placeholder rules, inventory + journal follow-ups |

Choices that differ from those sources, and why:

- **Single container, not two.** Upstream's two-container file splits agent
  and WebUI; here the simpler one-container shape — one thing to back up,
  one thing to update. Follows the owner's update habit (one recycle per
  stack) rather than the two-volume refresh dance.
- **Fresh named volumes, no bind mount of an existing `~/.hermes`.**
  Upstream mounts the operator's home directory in. That would hand over the
  owner's sessions and memory — the exact thing this stack exists to avoid.
- **Password default is the placeholder, override in Dokploy.** Upstream defaults it to empty for
  localhost use. A public domain with no password is an open chat to the
  internet; the compose carries `__PASTE_ONCE__` as its default so CI's
  `docker compose config` passes, and the Dokploy service environment MUST
  set the real value — a deploy keeping the placeholder has a publicly
  known password.
- **Port on loopback only.** Upstream's public variant publishes the port;
  here Dokploy's Traefik is the only ingress, same as every other VPS app.
- **No model or provider choice in the repo.** Model and keys are set inside
  the container after first boot — decided at deploy, recorded in the journal
  entry, not here.
- **No Hindsight bank name in the repo.** Memory is wired post-deploy inside
  the container's own config pointing at the shared Hindsight server; the
  bank name identifies whose memory it is, so it never lands in a public file.

## Deploying in Dokploy

Follows `skills/deploy-on-dokploy/` steps 4–7 and 9, with these differences:

- **Source:** this repo, branch `main`, compose path
  `apps/vps/hermes-webui/compose.yaml`. Auto-deploy off — downtime on every
  push to `main` helps nobody.
- **Environment (step 4):** `HERMES_WEBUI_PASSWORD` only (`.env.example`). Secrets go
  to OpenBao at `kv/homelab/hermes-webui/<key>` once foundations step 3 lands;
  until then the Dokploy service environment.
- **Domain:** public, Cloudflare DNS, Dokploy-managed. This is the one app
  in the repo whose admin UI is meant for someone without Tailscale, so the
  exception is recorded here rather than in `decisions/foundations-on-vps.md`
  (which stays tailnet-only as the default).
- **Post-deploy, inside the container** (recorded in the journal entry, never
  here): pick the model/provider, set the memory bank, confirm the password
  login works from outside the tailnet.
- **Backups:** the two named volumes to the Garage destination at home
  (step 9 of the skill), run once. Chat history is the state that matters —
  losing it to a volume prune is the failure mode.

## Data and backups

- `hermes-webui-home` holds the WebUI state: sessions, agent memory,
  config. The thing backed up.
- `hermes-webui-workspace` holds its files. Small by design.
- Neither volume is shared with any other stack. A restore touches this chat
  and nothing else.

## Tested

Not deployed, so: `docker compose config` only (CI). The Dokploy steps above
are UNTESTED — the first deploy corrects them and links its journal entry
here.
