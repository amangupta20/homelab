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
| nesquena/hermes-webui `docker-compose.yml` (single container) | tag v0.52.544, read 2026-10-27 | whole shape: one container, agent in-process, `HERMES_WEBUI_*` env names |
| nesquena/hermes-webui `docker_init.bash` | tag v0.52.544, read 2026-10-27 | the image has no agent of its own: it looks for one in `~/.hermes/hermes-agent` or `/opt/hermes`, and without one "the WebUI still serves without the agent" |
| nesquena/hermes-webui `docs/docker.md` | main, read 2026-10-27 | release-pair rule (WebUI and agent pinned and upgraded together) |
| This repo's `skills/deploy-on-dokploy/` | 2026-10-27 | file layout, placeholder rules, inventory + journal follow-ups |

Choices that differ from those sources, and why:

- **One container, not upstream's two-container layout** (owner,
  2026-10-27). It is the simplest shape to keep running for one person who
  will not tweak it: one thing to back up, one thing to update.
- **Fresh named volumes, no bind mount of an existing `~/.hermes`.**
  Upstream mounts the operator's home directory in, which is also where its
  agent comes from. That would hand over the owner's sessions and memory —
  the thing this stack exists to avoid — so the agent is put into the fresh
  volume once instead ("First deploy").
- **Pinned tag, not `latest`.** Upstream documents `latest` as its stable
  channel, but on 2026-10-27 `ghcr.io/nesquena/hermes-webui:latest` carried
  version label `0.52.560`, an `exp-v*` (experimental) release
  (`docker buildx imagetools inspect` on the arm64 image). 0.52.544 is the
  newest `v*` (stable) release. Both images used here are published for
  `arm64` (WebUI: `docker manifest inspect`; agent: Docker Hub tags API),
  checked 2026-10-27.
- **Password required.** Upstream defaults it to empty for localhost use.
  `${HERMES_WEBUI_PASSWORD:?}` makes the deploy fail when it is unset. CI
  validates with `.env.example` (`.github/workflows/ci.yml`).
- **No published port.** Upstream publishes 8787 on loopback; here Dokploy's
  Traefik is the only way in.
- **No model, provider or memory settings in the repo.** They are set inside
  the container after first boot and recorded in the deploy's journal entry.

## Deploying in Dokploy

Follows `skills/deploy-on-dokploy/` steps 4–7 and 9, with these differences:

- **Source:** this repo, branch `main`, compose path
  `apps/vps/hermes-webui/compose.yaml`. Auto-deploy off — downtime on every
  push to `main` helps nobody.
- **Environment (step 4):** `HERMES_WEBUI_PASSWORD` (`.env.example`). Its
  value lives in OpenBao at the path named there. Whether Dokploy can read it
  from OpenBao directly is `plans/vps-foundations.md` step 3, not done yet;
  until then it is copied into the Dokploy service environment by hand.
- **Domain:** public, Cloudflare DNS, Dokploy-managed, pointing at port 8787.
  Public for now, possibly tailnet-only later (owner, 2026-10-27). SSO is not
  up yet, so the app's own password is the only login;
  `plans/vps-foundations.md` lists it for SSO once that runs. Whether Dokploy
  joins the service to its Traefik network on its own is UNTESTED.

## First deploy: put the agent in the volume (UNTESTED)

After the first deploy has created the volume, copy the agent from its
pinned image into it, then restart the WebUI from Dokploy. On the VPS:

```bash
docker volume ls | grep hermes-webui-home   # Dokploy prefixes the name
docker run --rm --entrypoint sh \
  -v <volume name from above>:/dst \
  nousresearch/hermes-agent:v0.22.5 \
  -c 'cp -a /opt/hermes/. /dst/hermes-agent/'
```

`/opt/hermes` is where upstream's two-container file takes the agent source
from the same image. The WebUI log should then show "Hermes agent critical
imports verified".

After that, inside the WebUI (recorded in the journal entry, never here):
pick the model/provider, set up memory, confirm the password login works
from outside the tailnet.

## Upgrading (UNTESTED)

Change the WebUI tag in one commit, together with the agent version named in
the compose comment: a WebUI release and the agent release it was made
against. After redeploying, replace `hermes-agent/` in the volume by
repeating the copy above with the new agent tag (remove the old directory
first). The WebUI's own "update agent" button does not apply here.

## Data and backups

- `hermes-webui-home` holds the state: sessions, agent memory, config, and
  the agent's code. The thing backed up.
- `hermes-webui-workspace` holds the files the chat works on.
- **Backups (UNTESTED):** the plan is both volumes to the Garage destination
  at home (step 9 of the skill), run once, with a restore tried per
  `systems/backups.md` — a backup counts only when the restore works.
- Neither volume is shared with any other stack. The intent is that a restore
  touches this chat and nothing else — UNTESTED, never restored yet.

## Tested

Not deployed, so: `docker compose config` with `.env.example` only (locally
and in CI). Everything marked UNTESTED above is corrected by the first deploy,
which links its journal entry here.
