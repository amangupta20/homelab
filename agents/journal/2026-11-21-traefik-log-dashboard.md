# 2026-11-21 — traefik-log-dashboard and GoAccess on the home proxy, behind Authentik

**Who:** Claude Code (Opus 5.5)  **Scope:** `proxy-1` (`apps/homeserver/traefik/`), Authentik, OpenBao  **Mode:** write
**Task:** owner, in session: both view-only log dashboards in step B4a of `agents/plans/home-overhaul.md`  **Skill:** none

## What changed

- OpenBao: `kv/homelab/traefik-log-dashboard`, field `token` (64 hex characters from `openssl rand`, never printed).
- Authentik (API, as `akadmin`): proxy providers and applications `traefik-logs-home` and `goaccess-home`
  (forward-auth, single application, flows and mappings copied from `traefik-home`), each bound to
  `homelab-admins`, both added to the outpost `home`.
- `proxy-1`, by `ansible/proxy.yml`: `log-agent` and `log-dashboard` (traefik-log-dashboard 3.1.1), `goaccess`
  (GoAccess 1.12) and `goaccess-report` (busybox httpd 1.38.0), all pinned by digest; their folders under
  `/srv/traefik/`; `goaccess.conf`; the routes `traefik-logs.yml.j2` and `goaccess.yml.j2`; `.env` now mode 0600
  with the agent's token. Traefik and the outpost were not recreated.
- Each was tried first on the workstation (traefik-log-dashboard with a made-up log, GoAccess with a copy of the
  real one). Why GeoIP is off, the containers run as root and GoAccess's browser panels are empty:
  `apps/homeserver/traefik/NOTES.md`, "Log dashboards".

## Snapshot / backup taken

`/opt/traefik` and `/srv/traefik/letsencrypt` tarred to the owner's workstation before each deploy:
`~/backups/proxy-1-pre-log-dashboard-2026-11-21/` (12 entries) and `~/backups/proxy-1-pre-goaccess-2026-11-21/`
(13), each equal to the count on `proxy-1`. Not restored.

## How it was verified

- `ansible-playbook proxy.yml --check --diff` read before each run; each run changed the planned items only.
- `curl`, for both hostnames: without a session 302 to Authentik's sign-in, also with a forged
  `X-authentik-username` and for GoAccess's WebSocket; 500 with the outpost stopped; the agent answers 401
  without its token and returns the real log with it. Details: `apps/homeserver/traefik/NOTES.md`, "Log dashboards".
  `cache.home` and Traefik's dashboard answered as before.
- Memory on `proxy-1` (1 GiB at most): the four new containers use about 26 MiB together once settled
  (`docker stats`); 471 MiB available after.

## Still open

- The owner's browser sign-in to both dashboards. UNTESTED until then. Then keep the ones used.
- The access log is not rotated (`apps/homeserver/traefik/NOTES.md`, "Log dashboards").
