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
| `compose.yaml` | Traefik alone, read-only root filesystem, every capability dropped except binding ports 80 and 443 |
| `traefik.yml.j2` | static configuration: entry points (80 redirects to 443), the wildcard certificate, the file provider, the access log |
| `routes/<app>.yml.j2` | one route per app: hostname, then the app's `http://<address>:<port>`. Traefik rereads a changed file without a restart |

## Routes

| Name | Goes to | Sign-in |
|---|---|---|
| `cache.home.<zone>` | `cache-1`'s Caddy, `http://10.22.33.137:80`: Artifact Keeper's web UI, and Grafana at `/grafana/` | Authentik by OIDC, in each app (`apps/homeserver/artifact-keeper/NOTES.md`, "Sign-in") |

apt and Docker clients keep using `http://10.22.33.137` directly. Which sign-in an app gets, how
the names and certificate work, the token's scope, a browser gotcha and phase 2: `NOTES.md`.

To add an app: copy `routes/cache.yml.j2`, change the router and service names,
the hostname and the address, and run `ansible-playbook proxy.yml`. To remove one,
delete its file here and run the playbook: it deletes every route file on `proxy-1`
that no template produces (tested 2026-11-19 with a planted file; the rest kept serving).

## Secrets and data

- The Cloudflare DNS token comes from OpenBao (`kv/general/cloudflare`, field
  `zonedns`) as a mode-0400 file, never in the container's environment.
- The certificate and ACME account key, in `/srv/traefik/letsencrypt`, are not
  backed up: losing them only means a new certificate.
