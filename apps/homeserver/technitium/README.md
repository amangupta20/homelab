# Technitium: the home's DNS resolver

Technitium DNS Server answers DNS for the home: ad and tracker blocking (HaGeZi
Ultimate plus Threat Intelligence Feeds Medium), a cache, DNS over HTTPS to
Cloudflare and Quad9, and `*.home.<zone>` answered locally with the home proxy's
address. Runs on `oob-1`, the Raspberry Pi (`lab/systems/oob.md`), in Docker,
deployed by `ansible/oob.yml`; step B4b of `agents/plans/home-overhaul.md`, where
the design (Pi primary, VPS fallback, one cluster) and its measurements live.

**Status:** running on the Pi
(`agents/journal/2026-11-23-technitium-oob-1.md`). No client uses it yet: DHCP
and the tailnet still point at the router until the VPS node exists.

## Address and sign-in

DNS on port 53 and the web console on `http://<oob-1>:5380`, both from the home
subnet only (the Pi's firewall); tailnet clients arrive through the router's
subnet route. The console has its own `admin` login; the password is in OpenBao
(`kv/homelab/technitium`, field `admin_password`). Sign-in through Authentik and
a route on the home proxy are not set up.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | the container: pinned by digest, host networking, 640 MB memory cap |
| `allowlist.txt` | domains the blocklists may not block; the playbook makes the live list match it |

Blocklists, upstreams, who may query, the allowlist and the `home` zone are set
by `ansible/oob.yml` through Technitium's API on every run, so a change made in
the console is undone by the next run. Change them here and in the playbook.

## Data and backups

Settings, stats and logs in `/srv/technitium` on the Pi; not backed up, because
the playbook rebuilds the same server. How it was built, the API calls and the
gotchas: `NOTES.md`.
