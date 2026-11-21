# 2026-11-21 — Home Traefik dashboard behind Authentik, through a local outpost

**Who:** Claude Code (Opus 5.5)  **Scope:** `proxy-1` (`apps/homeserver/traefik/`), Authentik, OpenBao  **Mode:** write
**Task:** owner, in session: step 3 of the 2026-11-18 hand-off, forward-auth for the home Traefik dashboard  **Skill:** none

## What changed

- Authentik (API, as `akadmin`): proxy provider and application `traefik-home` (forward-auth, single application),
  a policy binding for `homelab-admins`, and a new proxy outpost `home` serving that provider.
- OpenBao: `kv/homelab/authentik-outpost-home`, fields `token` (the outpost's API token, never printed) and `outpost`.
- `proxy-1`, by `ansible/proxy.yml`: the outpost container `authentik-outpost` (2026.8.5, pulled through cache-1's ghcr
  remote) in the Traefik stack, its token as a file, `.env` with Authentik's address, and the route
  `routes/dashboard.yml.j2`. Traefik itself was not restarted; its static configuration changed in comments only.
- Why a local outpost and not the embedded one: `apps/homeserver/traefik/NOTES.md`, "Forward-auth".

## Snapshot / backup taken

`/opt/traefik` and `/srv/traefik/letsencrypt` tarred to the owner's workstation
(`~/backups/proxy-1-pre-outpost-2026-11-21/`): 9 entries, equal to the count on `proxy-1`. Not restored. `proxy-1`
holds nothing else: the VM is rebuilt by OpenTofu and this playbook.

## How it was verified

- `ansible-playbook proxy.yml --check --diff` read before the run; the run changed the planned files only.
- The outpost: running, healthy, no restarts; Authentik's API shows it checking in, version 2026.8.5.
- Without a session (`curl`): `/dashboard/` and `/api/rawdata` answer 302 to Authentik's sign-in, also with a forged
  `X-authentik-username`; the outpost's ping 204; `cache.home` 200. With the outpost stopped: 500; started again: 302.

## Still open

- The owner's browser sign-in to the dashboard. UNTESTED until then.
- The view-only log dashboards (`apps/homeserver/traefik/NOTES.md`, "Not done yet").
