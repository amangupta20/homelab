# 2026-11-21 — traefik-log-dashboard on the home proxy, behind Authentik

**Who:** Claude Code (Opus 5.5)  **Scope:** `proxy-1` (`apps/homeserver/traefik/`), Authentik, OpenBao  **Mode:** write
**Task:** owner, in session: the first of the view-only log dashboards in step B4a of `agents/plans/home-overhaul.md`  **Skill:** none

## What changed

- OpenBao: `kv/homelab/traefik-log-dashboard`, field `token` (64 hex characters from `openssl rand`, never printed).
- Authentik (API, as `akadmin`): proxy provider and application `traefik-logs-home` (forward-auth, single
  application, flows and mappings copied from `traefik-home`), a policy binding for `homelab-admins`, and the
  provider added to the outpost `home`, which serves `traefik-home` and `traefik-logs-home`.
- `proxy-1`, by `ansible/proxy.yml`: containers `log-agent` and `log-dashboard` (traefik-log-dashboard 3.1.1, pinned by
  digest), folders `/srv/traefik/log-agent` and `/srv/traefik/log-dashboard`, the route `routes/traefik-logs.yml.j2`,
  and `.env` now mode 0600 with the agent's token. Traefik and the outpost were not recreated.
- Before deploying, both images were tried on the workstation with a made-up log: read-only root filesystem, no
  capabilities, the agent's 401 without a token. Why GeoIP is off and the containers run as root:
  `apps/homeserver/traefik/NOTES.md`, "Log dashboards".

## Snapshot / backup taken

`/opt/traefik` and `/srv/traefik/letsencrypt` tarred to the owner's workstation
(`~/backups/proxy-1-pre-log-dashboard-2026-11-21/`): 12 entries, equal to the count on `proxy-1`. Not restored.

## How it was verified

- `ansible-playbook proxy.yml --check --diff` read before the run; the run changed the planned items only.
- Without a session (`curl`): `/`, `/api/agents`, `/index.html` answer 302 to Authentik's sign-in, also with a forged
  `X-authentik-username`; the outpost's ping 204; the wildcard certificate is served. With the outpost stopped: 500;
  started again: 302. `cache.home` still 200, `traefik.home/dashboard/` still 302.
- The agent: 401 without the token; with it, `/api/logs/status` reports the access log found and authentication on,
  and `/api/logs/access?lines=200` returns 162 entries from the real log.
- Memory on `proxy-1` (1 GiB at most): the dashboard about 63 MiB and the agent about 8 MiB (`docker stats`); 479 MiB
  available after.

## Still open

- The owner's browser sign-in to `traefik-logs.home.<zone>`, and whether the dashboard shows the traffic. UNTESTED
  until then.
- GoAccess, the second log dashboard; then keep the ones used.
- The access log is not rotated (`apps/homeserver/traefik/NOTES.md`, "Log dashboards").
