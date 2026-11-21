# 2026-11-22 — Home Traefik: access-log rotation and forward-auth header settings

**Who:** Claude Code (Opus 5.5)  **Scope:** `proxy-1` (`apps/homeserver/traefik/`)  **Mode:** write
**Task:** owner, in session: the tidy-up after the log dashboards (`agents/journal/2026-11-21-traefik-log-dashboard.md`)  **Skill:** none

## What changed

- `logrotate` installed on `proxy-1` from Debian, with `/etc/logrotate.d/traefik` from `logrotate.conf`: the access
  log rotates weekly (or past 50 MB) by copy and truncate, eight weeks kept. Why copy-and-truncate:
  `apps/homeserver/traefik/NOTES.md`, "Log dashboards".
- The `authentik` forward-auth middleware (`routes/dashboard.yml.j2`) now sets `trustForwardHeader: false` and
  `maxResponseBodySize: 1048576`; Traefik had warned that both were unset.
- Traefik restarted once, for a comment change in its static configuration from Prime's fix on PR #139.
- The owner signed in to both log dashboards in a browser and saw traffic (owner, 2026-11-22).

## Snapshot / backup taken

`/opt/traefik` and `/srv/traefik/letsencrypt` tarred to the owner's workstation
(`~/backups/proxy-1-pre-tidy-up-2026-11-22/`): 15 entries. Not restored.

## How it was verified

- `ansible-playbook proxy.yml --check --diff` read before the run; the run changed the planned items only. After
  the restart, Traefik's log held no warning for either setting.
- `curl`: `traefik`, `traefik-logs` and `goaccess` hosts answer 302 to Authentik, and with a forged
  `X-Forwarded-Host` the redirect still names the real host; `cache.home` 200; the outpost's ping 204.
- `logrotate --force` once: `access.log.1` holds the old log, the new file starts at byte 0, GoAccess kept counting
  (1477 then 1505 requests, read over its WebSocket), and the log agent returned the requests sent after it.

## Still open

- Which of the two log dashboards stay.
