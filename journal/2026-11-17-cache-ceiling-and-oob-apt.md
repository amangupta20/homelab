# 2026-11-17 — Cache ceiling, idle rule and generous caps; oob-1's apt through the cache; a dashboard

**Who:** Claude Code, at the owner's request  **Scope:** VM `cache-1` (Artifact Keeper), `oob-1`  **Mode:** write
**Task:** the owner asked for one shared limit instead of caps that add up to 80 GB, and for the Pi to use the cache  **Skill:** `skills/add-a-cache-remote/`

## What changed

- `cache-1`: the backend now runs with `STORAGE_QUOTA_BYTES` at 80 GB (`ansible-playbook cache.yml`;
  the backend, web UI and Caddy containers were recreated, PostgreSQL was not).
- `cache-1`: per-remote caps raised (Docker Hub 50 GB, ghcr.io 30, Debian 40, the rest 15) and two remotes
  added, `raspi` and `tailscale-apt`, by `cache-remotes.sh`. The same run created the lifecycle policy
  `cache-idle` (no download in 30 days) and assigned it to all seven remotes.
- `oob-1`: its four apt sources point at the cache (`ansible-playbook oob.yml`). The files it had before are
  in `/root/apt-sources-2026-11-17/` on the Pi.
- `cache-1`: Prometheus, node-exporter and Grafana added to the stack, with the backend's unauthenticated
  metrics listener on its internal port 9091; Grafana at `http://10.22.33.137/grafana/` (password in OpenBao,
  new field `grafana_admin_password`). The whole stack except PostgreSQL was recreated.

How the three limits work, and why there is no shared evicting cap:
`apps/homeserver/artifact-keeper/README.md`, "How it stays inside the disk".

## Snapshot / backup taken

None. The cache holds rebuildable state (`decisions/backup-tiers.md`); its settings come back from
`cache-remotes.sh`. On the Pi, only the apt source files changed, and they were copied first (above).

## How it was verified

- `GET /api/v1/admin/stats`: `storage_quota` enabled at 80,000,000,000 bytes, 0.33 % used.
- `cache-remotes.sh` run twice: the second run said `exists` for every remote and `cache-idle: updated`.
- A dry run of `cache-idle` (`POST /api/v1/admin/lifecycle/<id>/preview`) matched 0 cache entries with no
  `skipped_reason`, so the rule reaches the remotes' caches; nothing is 30 days old yet.
- `raspi` and `tailscale-apt`: `InRelease` and one package each fetched twice. The 32.8 MB Tailscale package took
  0.16 s the second time when fetched on `cache-1` itself; usage counters 2.0 MB and 32.8 MB.
- `oob-1`: `apt-get update` fetched all five suites from `10.22.33.137`; `apt-get download hello raspi-config`
  ran twice, and `ak_proxy_cache_lookups_total` counted hits for `debian` and `raspi`.
- Prometheus' targets page: both targets `up`, no error. Each dashboard query run against Prometheus: the
  gauges and VM panels returned data at once, the rate panels after a few minutes; the hit-rate panels need an
  hour of history. `curl http://10.22.33.137:9100/metrics` from the workstation got no answer.
- Memory in use went from about 690 MB to 880 MB of 1.5 GiB (`free -m`).

## Still open

- The Pi has 17 upgradable packages; they were not installed. `unattended-upgrades` takes the security ones
  through the cache.
- Switching the Pi back to upstream with `-e apt_cache=` is untested.
