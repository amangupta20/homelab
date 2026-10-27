# Second Hermes WebUI on the VPS

A second Hermes WebUI on the VPS for someone without lab access — a plain chat
page over a public domain, no Tailscale or SSH needed. The folder name is the
same as the upstream project; which Dokploy project it is and who uses it live
in Dokploy, not in this public repo.

**Status:** deployed on Dokploy 2026-10-27. The container starts, the domain
routes to it and the password login works; chat does not work yet, because the
agent has to be put into the volume once ("First deploy"). No `journal/` entry
yet.

## Derived from

Upstream base for later modifications (re-check these when upgrading):

| Source | Version read | What was taken |
|---|---|---|
| nesquena/hermes-webui `docker-compose.yml` (single container) | tag v0.52.544, read 2026-10-27 | whole shape: one container, agent in-process, `HERMES_WEBUI_*` env names |
| nesquena/hermes-webui `docker_init.bash` | tag v0.52.544, and again at the `0.52.561` build's revision `4d975aa` | the image has no agent of its own: it looks for one in `~/.hermes/hermes-agent` or `/opt/hermes` and serves without it; from `0.52.556` it also passes the agent's uv overrides to the install |
| nesquena/hermes-webui `docs/docker.md` | main, read 2026-10-27 | release-pair rule (WebUI and agent pinned and upgraded together) |
| nesquena/hermes-webui issue #8113, #8524, #8544 | read 2026-10-27 | why the agent install failed on an older tag: the venv must be built on Python 3.14 (#8113, fixed in 0.52.544), and from 0.52.556 the WebUI also passes the agent's own `[tool.uv]` override table to uv (#8524, fixed by #8544). 0.52.561 is the pinned tag used here — the first that needs no workaround |
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
- **Pinned tag, not `latest`.** On 2026-10-27, `latest` and `experimental`
  were the same build, three hours old, and ghcr also published numbered tags
  for it. This stack pins the number, `0.52.561`, so a redeploy cannot
  silently change version and a rollback is one line. 0.52.544 was tried
  first and dropped: it installs agent v0.22.5 only with a workaround for
  upstream #8524 (see Troubleshooting). Both images used here are published
  for `arm64` (checked in ghcr 2026-10-27).
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

## First deploy: put the agent in the volume

This image ships the WebUI only. It finds an agent in
`~/.hermes/hermes-agent` or `/opt/hermes`; with neither it still serves, and
the page reports that Hermes is not importable. The fresh volume has neither,
so the agent goes in once, after the first deploy has created the volume.
Copying it is not enough on the older 0.52.544 image — there the install of
its dependencies fails and the log shows the agent directory as `[ok]` while
imports fail (Troubleshooting) — which is why the tag below is 0.52.561.

On the VPS, into the `hermes-webui-home` volume:

```bash
docker volume ls | grep hermes-webui-home   # Dokploy prefixes the name
docker run --rm --entrypoint sh \
  -v <volume name from above>:/dst \
  nousresearch/hermes-agent:v0.22.5 \
  -c 'cp -a /opt/hermes/. /dst/hermes-agent/'
```

`/opt/hermes` is where upstream's two-container file takes the agent source
from the same image. The WebUI installs the agent's Python dependencies from
that copy into its own venv on the next start — nothing to run by hand.

Then restart the service in Dokploy and follow its log. The expected lines are,
in order:

- `-- Auto-detected UID` and the init script switching to `hermeswebui`;
- `!! WARNING: hermes-agent source mount is writable from the WebUI container`
  — expected in this one-container shape: the agent lives in the volume the
  WebUI owns, so it cannot also be a separate read-only mount. The warning is
  aimed at the two-container layout, where the agent is its own container;
- `== Existing virtual environment cannot satisfy the staged agent — rebuilding`
  on the first restart (the image's venv is Python 3.12, the agent needs
  3.14 — upstream #8113, fixed in this tag);
- `Using CPython 3.14` then `uv pip install` resolving **around 100 packages**
  and ending without `No solution found`;
- `[ok]` for the agent dir, and no `!! WARNING: the Hermes agent is installed
  but is NOT importable` line;
- `Hermes Web UI listening on http://0.0.0.0:8787`.

A resolution that installs ~58 packages instead of ~100 means the 3.14 gate
was dropped; `No solution found` naming `pillow` means the image is older than
0.52.556 (Troubleshooting).

After that, inside the WebUI (recorded in the journal entry, never here):
pick the model/provider, set up memory, confirm the password login works
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

## Upgrading (UNTESTED)

Change the WebUI tag in one commit, together with the agent version named in
the compose comment: a WebUI release and the agent release it was made
against. After redeploying, replace `hermes-agent/` in the volume by
repeating the copy above with the new agent tag (remove the old directory
first). The WebUI's own "update agent" button does not apply here.

Upgrade to a numbered tag, not `latest` or `experimental`: on 2026-10-27 both
of those followed the newest build (`0.52.561`), so they move without warning
and a redeploy could change version under the person using it.

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

- `docker compose config` with `.env.example` only (locally and in CI).
- Deployed on Dokploy 2026-10-27: the container starts and the domain routes to
  it — but only once `expose: 8787` is declared, which is why that line is
  there.
- The `0.52.561` tag was checked in ghcr, not by running it: its build
  (revision `4d975aa`, 2026-10-27T16:17Z) labels itself `0.52.561`, and its
  `docker_init.bash` extracts the agent's override table and installs with
  `uv pip install --overrides`, which is the upstream fix for #8524. The
  mechanism was verified offline: with that override, `uv pip install` of
  agent v0.22.5 resolves cleanly (~100 packages, `pillow==13.0.0`,
  `python-dotenv`, `ruamel-yaml`); without it, it fails with #8524's error.
- UNTESTED here: the agent copy as written above, the first boot on 0.52.561,
  and the backups.
- No `journal/` entry yet — the deploy is not finished.
