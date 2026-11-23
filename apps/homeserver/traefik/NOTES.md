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

The Authentik outpost's token (`kv/homelab/authentik-outpost-home`, field `token`) is written to
`/opt/traefik/secrets/authentik_outpost_token`, mode 0400, owned by user 1000, which the outpost's image runs as;
the outpost reads it through `AUTHENTIK_TOKEN=file://...`. Authentik's address is in `/opt/traefik/.env`.

The log dashboard's agent token (`kv/homelab/traefik-log-dashboard`, field `token`) goes into `/opt/traefik/.env`
as `LOG_AGENT_TOKEN`. That file is mode 0600, since neither the agent nor the dashboard reads a token from a file
(their configuration code reads plain environment variables, v3.1.1 source, read 2026-11-21). The compose file
uses `${LOG_AGENT_TOKEN:?}`, so a missing token stops the stack instead of starting the agent without
authentication.

The certificate and the ACME account key are in `/srv/traefik/letsencrypt`.
Not backed up: losing them only means Traefik requests a new certificate.

## Browsers with secure DNS

**Firefox and Zen with secure DNS (DNS over HTTPS):** they reject a private address
from their DNS provider, so `*.home.<zone>` fails with "trouble finding that site".
Set `network.trr.allow-rfc1918` to `true` in `about:config` (the owner's fix,
2026-11-18), or add `home.<zone>` to `network.trr.excluded-domains`.

## Forward-auth

For apps without their own single sign-on, and for view-only dashboards (the sign-in rule above). Traefik's
`forwardAuth` middleware asks Authentik's proxy outpost about every request; set up 2026-11-21 for the dashboard.

- **A local outpost, not Authentik's embedded one.** The embedded outpost runs inside Authentik on the VPS, behind
  the VPS's Traefik, which rewrites `X-Forwarded-Host` on requests from outside (no `forwardedHeaders.trustedIPs`
  in its static configuration, read 2026-11-21); the outpost would see Authentik's own hostname, not the app's. So
  an outpost `home` (Authentik API, as `akadmin`) runs in this stack as `authentik-outpost`. It connects out to
  Authentik's public address with its own token, and Traefik reaches it on the compose network. Its version
  follows the server's.
- **Single-application mode**, as for CloudBeaver on the VPS (`apps/vps/cloudbeaver/NOTES.md`, "Sign-in"): the
  session cookie is set on the protected hostname itself, through the outpost's `/outpost.goauthentik.io/` paths
  there, so it does not matter that Authentik is under another domain. The cookie-domain question raised in the
  first plan only applies to domain-level mode.
- **In Authentik:** a proxy provider `traefik-home` (forward-auth, single application, external host
  `https://traefik.home.<zone>`, CloudBeaver's provider's flows and mappings), an application `traefik-home` with a
  policy binding for `homelab-admins`, and the outpost `home` with that provider.
- **Closed when broken:** with the outpost stopped, the dashboard and its API answered 500, not the page (`curl`,
  2026-11-21). With Authentik itself down, the outpost cannot check a session either; that case was not tested.
- **Checked on 2026-11-21** (`curl`): without a session, `/dashboard/` and `/api/rawdata` answer 302 to Authentik's
  sign-in, also with a forged `X-authentik-username`; the outpost's `/outpost.goauthentik.io/ping` answers 204;
  `cache.home` still answers 200. Authentik's API shows the outpost checking in, version 2026.8.5. A browser sign-in
  by the owner: UNTESTED.
- **Forwarded headers** (2026-11-22): the middleware sets `trustForwardHeader: false`, so Traefik drops every
  `X-Forwarded-*` header a client sends and sets its own for the outpost, and `maxResponseBodySize` (1 MiB). Left
  unset, Traefik 3.7 warned about both (`pkg/middlewares/auth/forward.go`). Checked with `curl`: each protected
  hostname still answers 302, and with a forged `X-Forwarded-Host` the sign-in redirect still names the real host.
- **To protect another app:** add its provider to the outpost `home` in Authentik, and use `middlewares:
  [authentik]` plus its own `/outpost.goauthentik.io/` router in its route file, as `routes/dashboard.yml.j2` does.
  The outpost does not pick up a provider added to it at once: on 2026-11-23 `dns.home.<zone>` answered 400 ("no
  app for hostname", failing closed) until `docker compose restart authentik-outpost`, then 302 to the sign-in.
- **`dns.home.<zone>`** (2026-11-23): Technitium's console on `oob-1`. Provider `dns-home` copied from
  `traefik-home` (forward-auth, single application, same flows and mappings), application `dns-home` bound to
  `homelab-admins`, added to the outpost `home`; created through Authentik's API. Checked with `curl`: without a
  session `/`, `/index.html` and `/api/user/session/get` answer 302 to Authentik's sign-in, also with a forged
  `X-authentik-username`; the other dashboards still answer 302. A browser sign-in by the owner works (2026-11-23).

## Log dashboards

View-only dashboards of the access log (`/srv/traefik/log/access.log`, JSON), behind the same forward-auth as
Traefik's dashboard. The plan is to try them and keep the ones used (`agents/plans/home-overhaul.md`, step B4a).

- **traefik-log-dashboard** (hhftechnology, AGPL-3.0), release 3.1.1 from 2026-04-14 (GitHub releases, read
  2026-11-21). Set up 2026-11-21 at `traefik-logs.home.<zone>` (Authentik provider and application
  `traefik-logs-home`, `homelab-admins` only, on the outpost `home`). Two containers: `log-agent` parses the log
  and serves it over an API that needs a token, and `log-dashboard` is the web UI, with no login of its own.
- **GeoIP lookups off.** By default the dashboard sends client addresses to `ipwho.is` to draw its map (the
  project's example compose file adds `ip-api.com`; `dashboard/server/routes/location.ts`, v3.1.1). Clients here are LAN or tailnet addresses, so the map has
  nothing to show anyway. A local MaxMind database (`GEOIP_LOCAL_DB_PATH`) is the option if the public apps ever
  log here.
- **Not set:** Discord alerts, the mobile app, the agent's system view (it would show the container, not the VM).
- **Its data** (`/srv/traefik/log-agent`, the read position; `/srv/traefik/log-dashboard`, SQLite with the
  agent list and alert settings) is not backed up. The access log is the source, and the settings are in compose.
- **Root in the containers:** both images run as uid 0. With every capability dropped, root can read only files
  root owns, and the root filesystem is read-only. Running as another user would mean opening up the log folder (0750).
- **Checked on 2026-11-21** (`curl`): without a session, `/`, `/api/agents` and `/index.html` answer 302 to
  Authentik's sign-in, also with a forged `X-authentik-username`. With the outpost stopped they answer 500. The
  agent answers 401 without the token, and with it returns the real log (162 entries from 200 lines). A browser sign-in by
  the owner: works, and shows traffic (2026-11-22).
- **Access-log rotation** (`logrotate.conf`, set up 2026-11-22): weekly or past 50 MB, eight weeks kept, by
  `copytruncate`. Debian's systemd timer runs logrotate once a day (`logrotate.timer`, `OnCalendar=daily`, Debian's
  logrotate package), so both rules are checked daily. The log grew about 1.2 MB in three days (`ls`, 2026-11-21). Copy-and-truncate keeps the file in
  place: GoAccess exits if the log is briefly missing (`verify_inode`, `src/goaccess.c`, v1.12), and Traefik writes
  with `O_APPEND`, so it needs no signal. A forced rotation on 2026-11-22 (`logrotate --force`): the new file starts
  at byte 0, GoAccess kept counting (1477 then 1505 requests, read over its WebSocket), and the agent returned the
  requests sent after it. GoAccess's report only covers the current file, so its history starts again each week.
- **GoAccess** (MIT), release 1.12 from 2026-09-16 (Docker Hub tags, read 2026-11-21). Set up 2026-11-21 at
  `goaccess.home.<zone>` (Authentik provider and application `goaccess-home`, `homelab-admins` only, on the outpost
  `home`). `goaccess` follows the log and rewrites one HTML report in `/srv/traefik/goaccess`. `goaccess-report`
  (busybox's httpd) serves that page, and Traefik routes `/ws` to GoAccess's WebSocket for live updates, behind the
  same forward-auth. GoAccess refuses a WebSocket handshake whose `Origin` is another site (400, tested locally).
  GoAccess has no preset for Traefik's JSON log, so `goaccess.conf.j2` maps the fields; all 1,364 lines of the real
  log parsed with it, none failed (a one-off JSON report, 2026-11-21). Nothing is persisted: it rereads the whole
  log on every start.
- **No browsers, systems or referrers in GoAccess.** Traefik keeps no request headers in the JSON log by default,
  so there is no User-Agent or Referer to read. Keeping those two headers (`accessLog.fields.headers`) would fill
  those panels; not done, since it changes what the log holds about every visitor.
- **GoAccess checked on 2026-11-21** (`curl`): without a session, `/`, `/index.html` and `/ws` (also as a
  WebSocket upgrade) answer 302 to Authentik's sign-in, also with a forged `X-authentik-username`. With the
  outpost stopped, `/` and `/ws` answer 500 after about 8 seconds, while Traefik's lookup of the outpost's name
  fails. From inside the stack, the WebSocket answers 101. The owner signed in and saw traffic in a browser (2026-11-22).

## Not done yet (phase 2)

- **Which log dashboards stay:** both are on trial; drop the one not used.
- **Sablier wakeups.** No sleepable app at home yet; when there is one, pin the
  plugin and keep `plugins-storage` on disk (`agents/plans/home-overhaul.md`).
- **Pulling through the cache.** `proxy-1` pulls Traefik's image and its apt
  packages directly; the cache client playbook is step 4 of
  `agents/plans/package-and-image-cache.md`.

## Dates

When the facts in `README.md` were true from, or were checked.

- The route clean-up was tested on 2026-11-19 with a planted file.
- Forward-auth for the dashboard set up on 2026-11-21 (`agents/journal/2026-11-21-home-traefik-dashboard-sign-in.md`).
- traefik-log-dashboard and GoAccess set up and checked on 2026-11-21 (`agents/journal/2026-11-21-traefik-log-dashboard.md`).
- Access-log rotation and the forward-auth header settings on 2026-11-22 (`agents/journal/2026-11-22-traefik-tidy-up.md`).

## Resolvr

A dashboard for the Technitium DNS cluster (`apps/homeserver/technitium/`), MIT, release 1.3.2 from 2026-10-12
(GitHub releases, read 2026-11-23), at `resolvr.home.<zone>`. Set up 2026-11-23 at the owner's request; here on
`proxy-1` for now, which has room (1 CPU, about 477 MB free before it, `free -m`), and may move to `docker-1`.

- **One container:** `ghcr.io/bassem-elsodany/resolvr`, the image whose API also serves the web app
  (`docker/resolvr.Dockerfile`), through the cache's ghcr remote, amd64 and arm64.
- **No second login.** Resolvr's Home Assistant add-on mode, switched on with `RESOLVR_ADDON=true`, signs in any
  request whose connection comes from a trusted address, as admin, and judges that by the socket's peer, not a
  header (`backend/src/auth.ts`, `attachUser`; `backend/src/addon.ts`). The only trusted address is Traefik's fixed
  `172.31.250.2` on the `resolvr` network, which only Traefik and Resolvr join. So passing Authentik's
  forward-auth (`homelab-admins`; Authentik provider and application `resolvr-home`) is the sign-in. Resolvr's own
  seeded `admin` and `viewer` accounts get a random password from OpenBao (`kv/homelab/resolvr`, `seed_password`).
- **Its access to Technitium:** user `resolvr` on the Pi, view-only through the built-in Everyone group plus view on
  Settings and Administration (for the server and cluster pages); an API token named `resolvr-proxy-1` in OpenBao
  (`kv/homelab/resolvr`, `technitium_token`), written by `ansible/proxy.yml` into the add-on options file. Resolvr's
  admin actions (block a domain, edit feeds) are refused by Technitium for this user; lists come from the repo.
- **Checked on 2026-11-23** (`curl`, `docker exec`): without a session `/` and `/api/auth/me` answer 302 to
  Authentik's sign-in, also with a forged `X-Remote-User-Name`; from Traefik's address `/api/auth/me` returns the
  admin user; from the `proxy-1` host it answers 401 (reachable, not trusted); `/api/status` reports it connected
  to `oob-1.dns.home.arpa`, version 15.6.2, cluster initialised. With the token, Technitium refused a settings
  change ("Access was denied"). A browser sign-in by the owner: UNTESTED.
- **Query logs:** its query panels (Resolution, Clients, Query Logs) read Technitium's "Query Logs (Sqlite)" app,
  installed by `ansible/oob.yml` in memory only (two days or 10,000 records), so nothing is written to the Pi's SD
  card; the cluster copies it to the VPS node (`apps/vps/technitium/`). The logs reset when the container restarts.
