---
name: deploy-on-dokploy
description: Use when deploying an app on the VPS with Dokploy, or moving an app already running in Dokploy into this repo — writes the Compose definition under apps/vps/, wires secrets and sign-in, sets up backups, and records it.
---

# Deploy an app on Dokploy (VPS)

**Status:** UNTESTED — the Dokploy UI steps are from Dokploy's general
behaviour, not checked against the running instance. The first deploy fixes
them and links its journal entry here.
**Touches:** writes to the VPS (Dokploy) and to this repo.

## When to use / when not to

- Use for any app that belongs on the VPS (`decisions/vps-role.md`): it must
  stay up when home is down, other people use it, it needs more resources than
  home has, or it is a quick deploy.
- Not for home apps: they go in `apps/homeserver/`, and their container
  manager is still open.
- OpenBao itself is a foundation with its own steps (`plans/vps-foundations.md`),
  not an ordinary app.

## Before you start

1. Check `plans/vps-foundations.md`. Foundations come first
   (`decisions/foundations-on-vps.md`): if OpenBao or SSO are not up yet,
   stop and work on the plan instead. Deploy anyway only if the owner says so
   for this app; then its secrets go in Dokploy's environment for now, and
   the exception is written into the plan as a follow-up so the app gets
   revisited.
2. Decide what data the app keeps and how it will be backed up. No stateful
   app without a backup.
3. **Take a snapshot before writing to the VPS.** For a new app: a VPS
   snapshot from the provider, if it offers one, or a verified Dokploy backup
   of whatever the deploy could touch. For an app already running in Dokploy:
   a backup of its volumes and database, verified by restoring it once to a
   scratch location. Write down which snapshot or backup it was — it goes in
   the journal entry.
4. Pick the app's name: lowercase with hyphens. It is the folder name, the
   OpenBao path and the Dokploy service name.

## Steps

1. **Read the sources, then write your own.** Before writing anything, read
   Dokploy's template for the app (`blueprints/<name>/` in
   github.com/Dokploy/templates: `docker-compose.yml` and `template.toml`;
   the folder name may differ from the app's — OpenBao's nearest is `vault`)
   and the Compose file or container docs in the app's own repository. Do
   not copy either as is — templates often run dev modes, generate secrets
   into the environment, or attach a public domain. Check the image exists
   for `arm64`: the VPS is ARM (`systems/vps.md`):
   `docker manifest inspect <image>:<tag>` lists `"architecture": "arm64"`
   (run for `openbao/openbao:2.7.1`, 2026-10-26).
2. **Write the definition** in `apps/vps/<app>/` (rules: `apps/README.md`):
   - `compose.yaml` with image tags pinned (no `latest`), secrets and values
     that identify the lab (domains, public and tailnet IPs) as `${VAR}`,
     everything else written in (`apps/README.md`), and no admin port
     published publicly.
   - `.env.example` listing every variable and the OpenBao path it comes
     from, `kv/dokploy/<app>`, field `<key>`. Secrets get the placeholder
     `__PASTE_ONCE__`; a non-secret value that Compose checks, such as an IP
     address, gets a harmless value of the right shape instead, or step 3
     fails (`invalid IP address: __PASTE_ONCE__`).
   - `README.md` with a "Derived from" table: each source from step 1, the
     version or commit read, and what was taken; then the choices that
     differ from the sources and why. On an upgrade, compare the sources
     against those versions. Example: `apps/vps/openbao/README.md`. Add data
     location, ports and quirks as needed.
3. **Validate locally:** `cp apps/vps/<app>/.env.example /tmp/<app>.env` then
   `docker compose -f apps/vps/<app>/compose.yaml --env-file /tmp/<app>.env config`
   — expect the resolved config and no error (run for `openbao`,
   2026-10-26). CI runs
   `docker compose config` on every compose file (`.github/workflows/ci.yml`).
4. **Store the secrets:** in OpenBao at `kv/dokploy/<app>`, one field per
   key — Dokploy's token reads that folder only (`systems/openbao.md`, "Two
   container managers"). Never in the repo.
5. **Open a pull request** and get it through review. The intent is that
   Dokploy deploys only from `main`, so nothing goes live before the merge —
   how Dokploy pulls from this repo is still unverified
   (`decisions/open-questions.md`, Remote VPS); the first deploy confirms it.
6. **Create the service in Dokploy** (UI, UNTESTED paths): a new Compose
   service in the right project (an app already in Dokploy: switch its
   source from `raw`, where the Compose file is stored inside Dokploy, to
   git); source = this GitHub repo, branch `main`,
   compose path `apps/vps/<app>/compose.yaml`; environment from step 4;
   auto-deploy on push if the app should follow `main`. Expect: the first
   deploy shows the merge commit.
7. **Public access**, only if people outside the tailnet use it: add the
   domain in Dokploy and the DNS record in Cloudflare. Admin interfaces stay
   tailnet-only.
8. **Sign-in:** once SSO runs, register the app as an OIDC client if it
   supports it; otherwise put it behind the SSO's forward-auth. Write which in
   the app's `README.md`.
9. **Backups:** set up the Dokploy volume or database backup to the Garage
   destination at home, or the app's own backup, and run it once.

## Verify

- The app answers on its domain (or tailnet address) and its health check is
  green in Dokploy.
- Dokploy shows the deployed commit equal to `main`.
- For a stateful app: a backup exists in Garage **and** one restore was tried
  (`systems/backups.md` — a backup counts when a restore works).

## Stop if

- The app needs a secret committed to the repo, or an admin port on the
  public internet.
- A stateful app has no working backup.
- Dokploy wants to deploy from somewhere other than this repo's `main`.

Write down what you saw, and ask the owner.

## Afterwards

- Add or update the app's row in `inventory/services.md` (host: remote VPS,
  state with how it was verified).
- If the app needs more than a row, a page in `systems/`.
- Write `journal/YYYY-MM-DD-deploy-<app>.md`.
- If any step above was wrong, propose the fix to this skill
  (`skills/write-a-skill/`).
