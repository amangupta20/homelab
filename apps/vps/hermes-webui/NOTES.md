# Second Hermes WebUI on the VPS — notes

The sources, reasons, tests and gotchas behind `README.md`.

## Derived from

Upstream base for later modifications (re-check these when upgrading):

| Source | Version read | What was taken |
|---|---|---|
| nesquena/hermes-webui `docker-compose.yml` (single container) | tag v0.52.544, read 2026-10-27 | whole shape: one container, agent in-process, `HERMES_WEBUI_*` env names |
| nesquena/hermes-webui `docker_init.bash` | tag v0.52.544, and again at the `0.52.561` build's revision `4d975aa` | the image has no agent of its own: it looks for one in `~/.hermes/hermes-agent` or `/opt/hermes` and serves without it; from `0.52.556` it also passes the agent's uv overrides to the install |
| nesquena/hermes-webui `docs/docker.md` | main, read 2026-10-27 | release-pair rule (WebUI and agent pinned and upgraded together) |
| nesquena/hermes-webui issue #8113, #8524, #8544 | read 2026-10-27 | why the agent install failed on an older tag: the venv must be built on Python 3.14 (#8113, fixed in 0.52.544), and from 0.52.556 the WebUI also passes the agent's own `[tool.uv]` override table to uv (#8524, fixed by #8544). 0.52.561 is the pinned tag used here — the first that needs no workaround |
| nesquena/hermes-webui release `v0.52.723` ("Known issues"), issue #9213; NousResearch/hermes-agent releases `v0.23.1`–`v0.23.3`, issue #157091 and PR #157528 (open) | read 2026-11-21 | the pair in `compose.yaml`: WebUI 0.52.723 with agent v0.23.1, because v0.23.2 and v0.23.3 break tool turns on a custom chat-completions provider with encrypted reasoning (#157091), and v0.23.3 cannot delete sessions (#9213) |
| The `nousresearch/hermes-agent:v0.22.5` and `v0.23.1` images | 2026-11-21 | `/opt/hermes` holds the whole agent, venv included (2.2–2.3 GB); its `install-stamp.json` names the build commit, which `agent-src` compares |
| This repo's `agents/skills/deploy-on-dokploy/` | 2026-10-27 | file layout, placeholder rules, inventory + journal follow-ups |
| nesquena/hermes-webui `api/auth_oidc.py`, `api/auth.py`, `static/login.js`, README | tag v0.52.702, read 2026-11-20; the same files inside the running `0.52.561` image | native OIDC: the `HERMES_WEBUI_OIDC_*` names, on only when issuer, client ID, allow claim and allow values are all set; redirect URI defaults to `<request base>/api/auth/oidc/callback`; issuer must be `https` and resolve to a public address; with no password set, the login page hides the password form (#7056) |

Choices that differ from those sources, and why:

- **One container, not upstream's two-container layout** (owner,
  2026-10-27). It is the simplest shape to keep running for one person who
  will not tweak it: one thing to back up, one thing to update.
- **Fresh named volumes, no bind mount of an existing `~/.hermes`.**
  Upstream mounts the operator's home directory in, which is also where its
  agent comes from. That would hand over the owner's sessions and memory —
  the thing this stack exists to avoid — so the agent is put into the fresh
  volume once instead ("First deploy").
- **Pinned tags, not `latest` or `experimental`.** Checked in ghcr on
  2026-10-27: both of those tags resolved to one manifest labelled `0.52.561`
  (revision `4d975aa`), so they move without warning. This stack pins numbers,
  so a redeploy cannot silently change version and a rollback is a revert.
  Since 2026-11-21 both pins come from stable releases (`v0.52.723`, agent
  `v0.23.1`); the first pin, `0.52.561`, came from the registry because the
  newest git release then, `v0.52.544`, needed a workaround for upstream #8524
  (see Troubleshooting). Both images are published for `arm64` (`docker
  manifest inspect`, 2026-11-21).
- **The agent is copied in by the stack** (`agent-src`, 2026-11-21). Upstream's
  two-container file shares the agent image's `/opt/hermes` through a volume;
  here a one-shot service copies it into the home volume instead, so the
  WebUI keeps one volume and both halves of the release pair are pinned in
  one file. It copies only when the image's `install-stamp.json` differs from
  the volume's (a 2.3 GB copy otherwise runs on every deploy), into
  `hermes-agent.new` first, so a failed copy keeps the old agent. Tested
  locally with a stand-in image on 2026-11-21: first copy, skip on the same
  stamp, replace on a new stamp, other files in the volume kept, the WebUI
  waiting for it (`service_completed_successfully`).
- **Password required.** Upstream defaults it to empty for localhost use.
  `${HERMES_WEBUI_PASSWORD:?}` makes the deploy fail when it is unset. CI
  validates with `.env.example` (`.github/workflows/ci.yml`).
- **No published port.** Upstream publishes 8787 on loopback; here Dokploy's
  Traefik is the only way in.
- **No model, provider or memory settings in the repo.** They are set inside
  the container after first boot and recorded in the deploy's journal entry.

## Sign-in

Through Authentik by OIDC, with the WebUI's own OIDC login. In Authentik
(made through its API as `akadmin`): a group `hermes-webui-1`; an OAuth2/OpenID
provider `hermes-webui-1` with the settings of Langfuse's provider
(`apps/vps/langfuse/NOTES.md`, "Sign-in": confidential client, grant types
`authorization_code` and `refresh_token` set by hand, the same flows, signing
key and scopes `openid`, `email`, `profile`), redirect URI
`https://<this app's domain>/api/auth/oidc/callback` (strict); an application
with slug `hermes-webui-1`, and policy bindings for the groups `hermes-webui-1`
and `homelab-admins`, so Authentik turns anyone else away before the app sees
them. The client ID and secret are in OpenBao (`.env.example`).

The app checks the same thing again: `HERMES_WEBUI_OIDC_ALLOW_CLAIM=groups`
with those two group names. Authentik's default `profile` scope puts the
`groups` claim in the token (read from the mapping's expression).

Whoever uses this instance needs an Authentik account in `hermes-webui-1`; the
owner makes it in Authentik's admin UI. The shared password stays as a second
way in for now (owner's choice). To make it OIDC only: drop
`HERMES_WEBUI_PASSWORD` from compose, `.env.example` and the Dokploy
environment; the compose file still refuses to start without the OIDC values.

## Deploying in Dokploy

Follows `agents/skills/deploy-on-dokploy/` steps 4–7 and 9, with these differences:

- **Source:** this repo, branch `main`, compose path
  `apps/vps/hermes-webui/compose.yaml`. Auto-deploy off — downtime on every
  push to `main` helps nobody. Dokploy had it on until 2026-11-21, when the
  owner confirmed off and it was set through the API (`compose.update`,
  `autoDeploy: false`). Updates follow `agents/skills/update-hermes-webui/`.
- **Environment (step 4):** `HERMES_WEBUI_PASSWORD` and the four sign-in values
  (`.env.example`), whose values live in OpenBao at the path named there.
  Dokploy reads them at deploy time through its OpenBao provider, as
  `${{vault.<provider>.dokploy/hermes-webui:<field>}}`; nothing is copied into
  the service environment (`lab/systems/openbao.md`).
- **Domain:** public, Cloudflare DNS, Dokploy-managed, pointing at port 8787.
  Public for now, possibly tailnet-only later (owner, 2026-10-27). Sign-in
  through Authentik as well as the password ("Sign-in"). Whether Dokploy
  joins the service to its Traefik network on its own is UNTESTED.

## First deploy: the agent in the volume

This image ships the WebUI only. It finds an agent in `~/.hermes/hermes-agent`
or `/opt/hermes`; with neither it still serves, and the page reports that
Hermes is not importable. Since 2026-11-21 the `agent-src` service puts the
agent there on every deploy that changes it (above, "Choices"). Until then it
was copied by hand once, on 2026-10-27, with `docker run --rm --entrypoint sh
-v <home volume>:/dst nousresearch/hermes-agent:v0.22.5 -c 'cp -a /opt/hermes/.
/dst/hermes-agent/'`, which is what `agent-src` now does.

The WebUI installs the agent's Python dependencies from that copy into its
own venv on the next start — nothing to run by hand. The expected log lines,
in order:

- `-- Auto-detected UID` and the init script switching to `hermeswebui`;
- on an agent change, a new venv: `Using CPython 3.14` (the agent needs 3.14 —
  upstream #8113), then `Applying hermes-agent's [tool.uv] override-dependencies`
  and `uv pip install` resolving **around 100 packages** without
  `No solution found`;
- `Hermes agent critical imports verified` and `[ok]` for the agent dir, and no
  `!! WARNING: the Hermes agent is installed but is NOT importable` line;
- `Hermes Web UI listening on http://0.0.0.0:8787`.

On 0.52.561 the log also showed `!! WARNING: hermes-agent source mount is
writable from the WebUI container`, expected in this one-container shape. A
resolution of ~58 packages instead of ~100 means the 3.14 gate was dropped;
`No solution found` naming `pillow` means the image is older than 0.52.556
(Troubleshooting).

After the very first deploy, inside the WebUI (recorded in the journal entry,
never here): pick the model/provider, set up memory, confirm the login works
from outside the tailnet.

## Troubleshooting

The failures the first attempt hit, on the 0.52.544 image — both upstream, both
visible in the Dokploy log. Neither should appear on 0.52.561:

- `AIAgent not available -- check that hermes-agent is on sys.path`, with
  `sys.path entries mentioning hermes/agent: - /.hermes/hermes-agent` and
  `HERMES_WEBUI_AGENT_DIR: (not set)`. The agent is not in the volume yet — the
  `HOME` in that line is `/`, so it is the pre-install state. Run the copy
  above.
- `No solution found when resolving dependencies` / `browser-harness>=0.1.13
  depends on pillow==12.3.0 ... hermes-agent==0.0.0 and pillow==13.0.0 are
  incompatible`, after which the script says `Kept the existing virtual
  environment` and the WebUI serves with `missing modules: ['run_agent']`.
  Agent v0.22.5 pins Pillow 13 and its dependency pins 12.3.0; the agent
  resolves that in its own `[tool.uv]` table, which 0.52.544's
  `uv pip install -e` never read. Upstream #8524, fixed by #8544 in the
  releases from 0.52.556 on. The same failure means the image tag was moved
  back below 0.52.556.

## Upgrading

Follow `agents/skills/update-hermes-webui/`: check the newest releases, their
known issues and open bug reports, choose the pair, back up, bump both pins,
deploy, verify. Done once on 2026-11-21, 0.52.561 + v0.22.5 to 0.52.723 +
v0.23.1 (`agents/journal/2026-11-21-update-hermes-webui.md`). The WebUI's own
update buttons do not apply here.

## Tested

- `docker compose config` with `.env.example` only (locally and in CI).
- Deployed on Dokploy 2026-10-27 and answering on its domain. Routing took
  `expose: 8787`; without it the domain did not route, which is why that line
  is there.
- The agent install works end to end. After the copy, the container's first
  start logged `Downloading cpython-3.14`, `Applying hermes-agent's [tool.uv]
  override-dependencies (4 entries)`, `Resolved 106 packages`, then
  `Hermes agent critical imports verified` and `listening on...` (log read
  2026-10-27, image `0.52.561`). The setup config showed the agent dir `[ok]`
  and a Python 3.14 venv.
- The `0.52.561` tag was checked in ghcr before use: revision `4d975aa`,
  labelled `0.52.561`, and its `docker_init.bash` extracts the agent's override
  table and installs with `uv pip install --overrides` (the fix for #8524). The
  mechanism was also checked offline with `uv`: agent v0.22.5 fails without the
  override and resolves with it.
- Provider setup: a custom OpenAI-compatible provider is read-only in the WebUI
  panel ("Edit it from the CLI or config file"), so it was configured with
  `docker exec -it -u hermeswebui -e HOME=/home/hermeswebui <container>
  /app/venv/bin/hermes model`, which writes `~/.hermes/config.yaml` and `.env`
  in the volume (owner, 2026-10-27).
- Upgrade to 0.52.723 + agent v0.23.1 on 2026-11-21: `agent-src` logged `agent
  copied` with `displayVersion` 0.23.1; the WebUI resolved 103 packages, logged
  `Hermes agent critical imports verified` and became healthy with no restarts;
  `hermes --version` printed v0.23.1; the session count was unchanged (31);
  `/api/auth/status` still had OIDC and password on; the public URL answered
  302 to `/login` and `/api/sessions` 401 (`curl`).
- A chat turn with a tool call after the upgrade works (owner, 2026-11-21, answering a request for one that uses a tool).
- Still UNTESTED: the backups below, and a restore.

## Dates

When the facts in `README.md` were true from, or were checked.

- Deployed on Dokploy on 2026-10-27; the owner checked the login, provider and chat that day.
- Sign-in through Authentik set up on 2026-11-20 (`agents/journal/2026-11-20-hermes-webui-sign-in-authentik.md`).
- Upgraded to WebUI 0.52.723 and agent v0.23.1 on 2026-11-21; Dokploy auto-deploy turned off the same day.
