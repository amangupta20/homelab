# 2026-11-09 — added a DNS-01 certificate resolver to Traefik

**Who:** the owner, with Claude Code  **Scope:** `dokploy-traefik` on the Remote VPS  **Mode:** write
**Task:** the wildcard certificate in `plans/shared-postgres.md` ("Certificates"), for the admin pages to come  **Skill:** none

## What changed

- `/etc/dokploy/traefik/traefik.yml`: a second resolver, `cloudflare`, with `dnsChallenge` (provider `cloudflare`,
  Cloudflare's two public DNS resolvers on port 53) and storage `dynamic/acme-cloudflare.json`. `letsencrypt` is unchanged.
- `/etc/dokploy/traefik/dynamic/.cf-dns-token` (root, mode 600): the token from OpenBao `kv/general/cloudflare`,
  field `zonedns`, written over SSH from stdin.
- Traefik's env, through the Dokploy MCP (`settings-writeTraefikEnv`): `CF_DNS_API_TOKEN_FILE` pointing at that file.
  This recreated the Traefik container; sites were down from about 09:23:50 to 09:24:10 UTC (Blinko polled every 3 s).
  Dokploy v0.31.0 recreates the container and leaves `traefik.yml` alone (`writeTraefikSetup`, read in its source).

Dokploy's own "DNS providers" (`dnsProvider.*` in its API) manage DNS records, not certificates, so they were not used.

## Snapshot / backup taken

`traefik.yml.bak-20261109` next to the file, and `~/backups/acme.json.bak-20261109` on the VPS. The new config was
parsed as YAML before the restart.

## How it was verified

- The token: Cloudflare's `/user/tokens/verify` says `active`, and it lists one zone.
- After the restart: Traefik running with `CF_DNS_API_TOKEN_FILE` in its env, and no new errors from the change in its log.
  Blinko answered 200 through its Sablier middleware, so the plugin loaded.
- A throwaway `traefik/whoami:v1.11.0` container with a router asking the `cloudflare` resolver for the zone and its
  wildcard: `acme-cloudflare.json` holds one certificate for the zone with `*.` as its other name, and `openssl
  s_client` for the test host got it, issued by Let's Encrypt. The container and image were removed.
- Blinko's domain still serves its own certificate, not the wildcard.

## Still open

- Whether Traefik renews the wildcard while no router uses it is not checked. It is valid for 90 days, and the
  first admin page will use it.
- Whether a Dokploy update keeps `CF_DNS_API_TOKEN_FILE` when it recreates Traefik is not checked. If it is lost,
  `letsencrypt` sites are unaffected, but DNS-01 renewals fail.
- The renewal error already seen in the handoff appeared again, for one host on the `letsencrypt` resolver
  ("unable to communicate with the API server"). Not investigated.
