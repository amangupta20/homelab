# Traefik — notes

The design, rules, gotchas and open work behind `README.md`.

## How names and the certificate work

One reverse proxy for internal apps. Every internal name is
`<app>.home.<zone>`: one public wildcard record points at `proxy-1`'s LAN
address (`iac/proxy-vm.tf`), so any resolver that forwards to the internet
answers it, and only the LAN and the tailnet (through the router's subnet
route) can reach it. One wildcard certificate covers every name, issued by
Let's Encrypt over the DNS challenge through Cloudflare's API, so nothing at
home has to be reachable from the internet and app names stay out of
certificate-transparency logs.

## Sign-in rule

**Sign-in rule** (owner, 2026-11-18): an app that supports single sign-on itself
(OIDC or OAuth2) signs in through Authentik that way, keeping a local admin for when
Authentik is unreachable; forward-auth at this proxy is only for apps without it, and
for view-only dashboards. Never both on one app.

## Secrets

The Cloudflare token (`kv/general/cloudflare`, field `zonedns`; it may read the
zone and edit its DNS records, nothing else, checked 2026-11-18) is written to
`/opt/traefik/secrets/cf_dns_api_token`, mode 0400. lego, Traefik's ACME
client, reads it through `CF_DNS_API_TOKEN_FILE`, so it is not in the
container's environment.

The certificate and the ACME account key are in `/srv/traefik/letsencrypt`.
Not backed up: losing them only means Traefik requests a new certificate.

## Browsers with secure DNS

**Firefox and Zen with secure DNS (DNS over HTTPS):** they reject a private address
from their DNS provider, so `*.home.<zone>` fails with "trouble finding that site".
Set `network.trr.allow-rfc1918` to `true` in `about:config` (the owner's fix,
2026-11-18), or add `home.<zone>` to `network.trr.excluded-domains`.

## Not done yet (phase 2)

- **Forward-auth through Authentik**, for Traefik's dashboard. Authentik runs on the VPS, outside
  `home.<zone>`, so forward-auth's cookie domain needs working out first
  (domain-level mode needs Authentik under the cookie domain). The dashboard
  is on in the static configuration, but no route leads to it until then.
- **The view-only dashboards** (traefik-log-dashboard, GoAccess), which read
  the access log in `/srv/traefik/log`.
- **Sablier wakeups.** No sleepable app at home yet; when there is one, pin the
  plugin and keep `plugins-storage` on disk (`agents/plans/home-overhaul.md`).
- **Pulling through the cache.** `proxy-1` pulls Traefik's image and its apt
  packages directly; the cache client playbook is step 4 of
  `agents/plans/package-and-image-cache.md`.
