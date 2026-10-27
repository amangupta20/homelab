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
| nesquena/hermes-webui `docker-compose.two-container.yml` | tag v0.52.544, read 2026-10-27 | whole shape: agent gateway + WebUI, shared home volume, agent source mounted read-only into the WebUI, env names |
| nesquena/hermes-webui `docs/docker.md` | main, read 2026-10-27 | release-pair rule (agent and WebUI pinned and upgraded together), agent-source volume refresh on upgrade |
| nesquena/hermes-webui `docker_init.bash` | tag v0.52.544, read 2026-10-27 | the WebUI image has no agent of its own: it looks for one in `~/.hermes/hermes-agent` or `/opt/hermes`, and without one "the WebUI still serves without the agent" |
| This repo's `skills/deploy-on-dokploy/` | 2026-10-27 | file layout, placeholder rules, inventory + journal follow-ups |

Choices that differ from those sources, and why:

- **Two containers, not upstream's single-container quick start.** The
  single-container file mounts the operator's existing `~/.hermes`, where the
  agent is installed. This stack starts from an empty home, so the agent has
  to come from its own image (`docker_init.bash` above).
- **Fresh named volumes, no bind mount of an existing `~/.hermes` or
  `~/workspace`.** Mounting them would hand over the owner's sessions and
  memory — the thing this stack exists to avoid.
- **Pinned tags, not `latest`.** Upstream documents `latest` as its stable
  channel, but on 2026-10-27 `ghcr.io/nesquena/hermes-webui:latest` carried
  version label `0.52.560`, an `exp-v*` (experimental) release
  (`docker buildx imagetools inspect ... --format` on the arm64 image). Both
  tags are published for `arm64` (WebUI: `docker manifest inspect`; agent:
  Docker Hub tags API), checked 2026-10-27.
- **No `container_name`.** Upstream names its containers `hermes-agent` and
  `hermes-webui`; on a host that already runs Hermes those names collide.
- **No published ports.** Upstream publishes 8787 and 8642 on loopback; here
  Dokploy's Traefik is the only way in, and the gateway is reached only over
  the stack's own network.
- **Password and gateway key required.** Upstream defaults both to empty for
  localhost use. `${VAR:?}` makes the deploy fail when either is unset.
  CI validates with `.env.example` (`.github/workflows/ci.yml`).
- **UID/GID written in as 1000.** Upstream reads them from the host user so
  bind mounts line up; with named volumes there is no host directory to
  match.
- **No model, provider or memory settings in the repo.** They are set inside
  the container after first boot and recorded in the deploy's journal entry.

## Deploying in Dokploy

Follows `skills/deploy-on-dokploy/` steps 4–7 and 9, with these differences:

- **Source:** this repo, branch `main`, compose path
  `apps/vps/hermes-webui/compose.yaml`. Auto-deploy off — downtime on every
  push to `main` helps nobody.
- **Environment (step 4):** the two variables in `.env.example`. Their values
  live in OpenBao at the paths named there. Whether Dokploy can read them
  from OpenBao directly is `plans/vps-foundations.md` step 3, not done yet;
  until then the values are copied into the Dokploy service environment by
  hand.
- **Domain:** public, Cloudflare DNS, Dokploy-managed, pointing at
  `hermes-webui` port 8787. Public for now, possibly tailnet-only later
  (owner, 2026-10-27). SSO is not up yet, so the app's own password is the
  only login; `plans/vps-foundations.md` lists it for SSO once that runs.
  Whether Dokploy joins the service to its Traefik network on its own is
  UNTESTED.
- **Post-deploy, inside the container** (recorded in the journal entry, never
  here): pick the model/provider, set up memory, confirm the password login
  works from outside the tailnet.
- **Backups (UNTESTED):** the plan is `hermes-webui-home` and
  `hermes-webui-workspace` to the Garage destination at home (step 9 of the
  skill), run once, with a restore tried per `systems/backups.md` — a backup
  counts only when the restore works.

## Upgrading

Change both image tags in one commit, to a WebUI release and the agent
release it was made against. Then, before redeploying, remove the
`hermes-webui-agent-src` volume so it is filled again from the new agent
image (upstream `docs/docker.md`, "Upgrading the agent container"). UNTESTED.

## Data and backups

- `hermes-webui-home` holds the state: sessions, agent memory, config. The
  thing backed up.
- `hermes-webui-workspace` holds the files the chat works on.
- `hermes-webui-agent-src` is the agent's code, rebuilt from the image. Not
  backed up.
- No volume is shared with any other stack. The intent is that a restore
  touches this chat and nothing else — UNTESTED, never restored yet.

## Tested

Not deployed, so: `docker compose config` with `.env.example` only (locally
and in CI). The Dokploy steps above are UNTESTED — the first deploy corrects
them and links its journal entry here.
