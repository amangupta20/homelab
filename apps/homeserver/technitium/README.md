# Technitium: the home's DNS resolver

Technitium DNS Server answers DNS for the home: ad and tracker blocking (HaGeZi
Ultimate plus Threat Intelligence Feeds Medium), a cache, DNS over HTTPS to
Cloudflare and Quad9, and `*.home.<zone>` answered locally with the home proxy's
address. Runs on `oob-1`, the Raspberry Pi (`lab/systems/oob.md`), in Docker,
deployed by `ansible/oob.yml`; step B4b of `agents/plans/home-overhaul.md`, where
the design (Pi primary, VPS fallback, one cluster) and its measurements live.

**Status:** running on the Pi
(`agents/journal/2026-11-23-technitium-oob-1.md`), as the primary node of the
DNS cluster (the VPS joins as secondary: `apps/vps/technitium/`). The router hands
it out by DHCP and forwards to it (`lab/systems/notes/router.md`, "DNS through the Pi").

## Address and sign-in

DNS on port 53 from the home subnet (the Pi's firewall); tailnet clients arrive
through the router's subnet route. The web console is at `https://dns.home.<zone>` through the home proxy, behind
Authentik's forward-auth (`homelab-admins`; `apps/homeserver/traefik/`); then
"Login with SSO" signs in through Authentik too (OIDC client `dns-console`), so
there is no second password. The local `admin` (OpenBao `kv/homelab/technitium`)
stays for the playbook; `http://<oob-1>:5380` works from the home subnet.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | the container: pinned by digest, host networking, 640 MB memory cap |
| `allowlist.txt` | domains the blocklists may not block; the playbook makes the live list match it |

Blocklists, upstreams, who may query, the allowlist, the `home` zone and the
cluster are set by `ansible/oob.yml` through Technitium's API on every run, so a change made in
the console is undone by the next run. Change them here and in the playbook.

## Data and backups

Settings, stats and logs in `/srv/technitium` on the Pi; not backed up, because
the playbook rebuilds the same server. How it was built, the API calls and the
gotchas: `NOTES.md`.
