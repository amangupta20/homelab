# Traefik: the home reverse proxy

One reverse proxy for internal apps at `<app>.home.<zone>`, with one wildcard
Let's Encrypt certificate; only the LAN and the tailnet can reach it. Runs on
`proxy-1` (`iac/proxy-vm.tf`), deployed by `ansible/proxy.yml`; phase 1 of step B4a
of `agents/plans/home-overhaul.md`.

**Status:** running (`agents/journal/2026-11-18-build-proxy-1-traefik.md`).

The zone is not in this public repo: `ansible/proxy.yml` reads it from OpenBao
(`kv/general/cloudflare`, field `zone`) into `traefik.yml.j2` and the routes.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | Traefik, read-only root filesystem, every capability dropped except binding ports 80 and 443; Authentik's proxy outpost for forward-auth; traefik-log-dashboard's agent and dashboard; GoAccess and the web server for its report. All but Traefik have no capabilities and no published port, and all are read-only |
| `goaccess.conf.j2`, `logrotate.conf` | GoAccess's configuration (reading Traefik's JSON log, the WebSocket); weekly rotation of the access log |
| `traefik.yml.j2` | static configuration: entry points (80 redirects to 443), the wildcard certificate, the file provider, the access log |
| `routes/<app>.yml.j2` | one route per app: hostname, then the app's `http://<address>:<port>`. Traefik rereads a changed file without a restart |

## Routes

| Name | Goes to | Sign-in |
|---|---|---|
| `cache.home.<zone>` | `cache-1`'s Caddy, `http://<cache-1>:80`: Artifact Keeper's web UI | Authentik by OIDC, in each app (`apps/homeserver/artifact-keeper/NOTES.md`, "Sign-in") |
| `traefik.home.<zone>` | Traefik's own dashboard (`api@internal`), at `/dashboard/` | Authentik forward-auth through the local outpost, `homelab-admins` only (`NOTES.md`, "Forward-auth") |
| `traefik-logs.home.<zone>`, `goaccess.home.<zone>` | the view-only log dashboards in this stack: traefik-log-dashboard (`log-dashboard:3000`) and GoAccess's report (`goaccess-report:8080`, live updates at `/ws`) | Authentik forward-auth through the local outpost, `homelab-admins` only (`NOTES.md`, "Log dashboards") |

apt and Docker clients keep using `http://<cache-1>` directly (`lab/inventory/network.md`). Which sign-in an app gets, how the names and certificate work, the token's scope, a browser gotcha and phase 2: `NOTES.md`.

To add an app: copy `routes/cache.yml.j2`, change the router and service names,
the hostname and the address, and run `ansible-playbook proxy.yml`. To remove one,
delete its file here and run the playbook: it deletes every route file on `proxy-1`
that no template produces (tested with a planted file; the rest kept serving).

## Secrets and data

Tokens come from OpenBao: Cloudflare's and the outpost's as mode-0400 files, the log agent's in the root-only `.env`
(it reads only its environment). The certificate and the log dashboard's data are not backed up (`NOTES.md`, "Secrets").
