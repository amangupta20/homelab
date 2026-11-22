# Artifact Keeper on cache-1 — notes

The sources, reasons, tests and gotchas behind `README.md`.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | backend, PostgreSQL (with TLS, as upstream), web UI and Caddy, trimmed from upstream's `docker-compose.yml` at commit `825b75e9`. Its Prometheus, node-exporter and Grafana were removed on 2026-11-22 ("Metrics") |
| `Caddyfile` | plain HTTP on port 80: the API, the registry (`/v2`), the Debian, npm, PyPI and generic formats go to the backend, the rest to the web UI |
| `init-pg-ssl.sh` | upstream's script that turns on TLS in PostgreSQL at first start, unchanged |
| `remotes.txt` | the one list of remote repositories and their caps, read by `cache-remotes.sh` and, later, the client playbook; add one with `agents/skills/add-a-cache-remote/` |
| `cache-remotes.sh` | creates the repositories in `remotes.txt` on cache-1, sets their caps and keeps the 30-day idle rule assigned to all of them; refuses a cap over the instance ceiling; safe to run again |

Deployed by `ansible/cache.yml`, which also writes the secret files from OpenBao
(`kv/homelab/artifact-keeper`: `db_password`, `jwt_secret`, `admin_password`,
`oidc_client_secret`) and a `.env` with the values `compose.yaml` fills in
(`.env.example` lists them: the zone, Authentik's hostname and the client ID). The local
admin user is `admin`. The `grafana_*` fields in OpenBao are left over from Grafana.

## Sign-in

At `https://cache.home.<zone>/`, through the home proxy (`apps/homeserver/traefik/`), the
web UI signs in through Authentik by OIDC (2026-11-18). Grafana did too until it was
removed on 2026-11-22; its Authentik application `cache-grafana` is unused since:

| App | Authentik application and provider | Callback | Admins |
|---|---|---|---|
| Artifact Keeper | `artifact-keeper` | `/api/v1/auth/sso/oidc/callback` | Authentik group `homelab-admins` (`OIDC_ADMIN_GROUP`); others get the default role |
| Grafana (removed 2026-11-22) | `cache-grafana` | `/grafana/login/generic_oauth` | `homelab-admins` become Admin, everyone else Viewer (`GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH`) |

Both providers copy Langfuse's settings (`apps/vps/langfuse/NOTES.md`, "Sign-in"),
including the explicit grant types an API-made provider needs; made through Authentik's
API on 2026-11-18. `homelab-admins` holds the owner's everyday account, not `akadmin`,
which Authentik refuses outside the tailnet. A first sign-in creates the account. The
owner's first sign-ins worked in both apps, as admin (2026-11-18,
`agents/journal/2026-11-18-cache-1-sign-in-authentik.md`).

Artifact Keeper keeps its local `admin` login next to the Authentik button; its
provider is seeded from the `OIDC_*` variables on every boot, and removing them and
restarting disables it again.

`AK_EXTERNAL_URL` is the `https://cache.home.<zone>` name, because the OIDC callback is
built from it. It also sets the registry's token address (`WWW-Authenticate` realm
`https://cache.home.<zone>/v2/token`), so a Docker client using the cache by its IP
fetches its token through the home proxy: it must resolve the name and reach `proxy-1`.
A token from there works on the IP (`curl`, 2026-11-18). No Docker client uses the mirror
yet.

## How it stays inside the disk

Three limits, all in GB of 10^9 bytes (owner, 2026-11-17, replacing the
2026-11-16 rule that the caps add up to 80 GB). Artifact Keeper has no shared
cap that evicts across repositories or a group of them (its source at
`e808fda`, 2026-11-17), so this is the closest it gets:

- **A cap per repository** (`remotes.txt`, generous on purpose). Over it, the
  repository evicts its own least recently used entries. Read one with
  `GET /api/v1/repositories/<key>/proxy-cache-cap` (admin token).
- **An 80 GB ceiling across everything** (`STORAGE_QUOTA_BYTES` in
  `compose.yaml`, on a 100 GB disk). It evicts nothing: at it, remotes still
  answer but store nothing new. The caps add up to more than it.
- **An idle rule:** a lifecycle policy, `cache-idle`, deletes entries not
  served for 30 days. It goes by each entry's last serve, not by when it was
  cached, so a file fetched yesterday stays. It runs every 6 hours and must be
  assigned to each remote by name (a global policy does not reach a remote's
  cache); `cache-remotes.sh` does both. A dry run on 2026-11-17 matched
  nothing, as expected for a two-day-old cache.

If the ceiling is ever hit with every repository under its cap, the cache
passes downloads through without storing until the idle rule frees space.
`GET /api/v1/admin/stats` shows `storage_quota.percent`.

## Metrics

The backend serves its metrics without a login on a second port (`METRICS_PORT=9091`),
reachable only on the stack's own network, for the lab's central monitoring once it is
chosen (`agents/plans/home-overhaul.md`, A6). Until 2026-11-22 Prometheus, node-exporter
and Grafana ran in this stack and drew them (owner, 2026-11-17); they were removed when
cache-1 ran out of memory, Grafana alone using about 356 MiB of its 1.5 GiB
(`agents/journal/2026-11-22-cache-1-memory-and-grafana.md`). Their files are in git
history.

Meaning of the counters, if you query them yourself:

- `ak_proxy_cache_lookups_total{repository, result}`: `hit` is served from
  disk; `miss_no_metadata` is a file not cached yet and `miss_expired` one
  past its time to live, both fetched upstream; `miss` comes from a second
  lookup path the backend also counts (meanings read from `metrics_service.rs`
  and `proxy_service.rs`, not traced request by request). Reset when the
  backend restarts.
- `ak_transfer_used_bytes`: bytes served this month, kept in PostgreSQL.
- `ak_storage_used_bytes` and `ak_storage_quota_bytes`: stored bytes and the
  ceiling.

Nothing reports bytes fetched from upstream. The removed dashboard estimated it as new
stored bytes plus bytes evicted by the caps, which misses downloads passed through
without storing.

## Deduplication

None across repositories with this storage backend. Files are stored per
repository (`proxy-cache/<repository>/<path>`), and the backend counts a file
present in two repositories as two (`storage_stats_service.rs`: on the
filesystem backend `shared_bytes` is always 0; only S3, GCS or Azure backends
share one copy). Within a repository a file is stored once. In practice the
remotes hold different upstreams, so the overlap is small: mostly base image
layers that exist on both Docker Hub and ghcr.io.

## Quirks

- **No apt remote for GitHub CLI** (2026-11-22). Its archive root, `https://cli.github.com/packages`, ends in
  `/packages`, and the backend refuses any Debian upstream whose path ends that way, as if it pointed at a
  `Packages` index (`is_debian_flat_or_mirrorlist`, `backend/src/services/repository_service.rs` on `main`,
  read 2026-11-22; `cache-remotes.sh` got a 400 `VALIDATION_ERROR`). A trailing slash is trimmed first, so it
  cannot be worked around in the URL. `gh` comes from the `github-releases` remote instead, pinned by its digest.
- **The first fetch from GitHub is slow** (133 s for the 15 MB gh `.deb` on 2026-11-22, then 0.15 s from the
  cache), most likely the router's GitHub detour (`agents/decisions/open-questions.md`, "Home network"). npm and Node
  were fetched twice the same day: npm metadata for `@openai/codex` 5.2 s then 0.19 s, Node 26.8.2's 33 MB
  tarball 6.4 s then 0.39 s, its SHA-256 equal to Node's `SHASUMS256.txt`.
- **Plain HTTP.** apt checks package signatures itself and Docker checks image
  digests, so the transport adds no trust. Docker daemons must list
  `10.22.33.137` under `insecure-registries` to use it.
- **The backend is `main`, pinned by digest**, until a release carries the
  per-remote cap (plan, "Which image").
- **A format not in the `Caddyfile`** reaches the web UI and gets an HTML 404.
  Add its prefix there when a new kind of remote is added.
- **A broken upstream download is not cached.** When ghcr.io's stream broke
  partway on 2026-11-16, the backend closed the client's connection and cached
  nothing (`upstream body failed … nothing cached`); the next request fetched it
  again.
- **First fetches from GitHub-hosted registries are slow from the LAN** while
  LAN traffic forwarded into the router's GitHub detour runs at about 125 kB/s
  (`agents/decisions/open-questions.md`). Later requests are served from disk.

## Dates

When the facts in `README.md` were true from, or were checked.

- Running since 2026-11-16.
- Clients: `oob-1` through `ansible/oob.yml` from 2026-11-17; `proxy-1` (apt and the Docker Hub mirror) and the rest of `lan_cache_clients` through `ansible/cache-client.yml` from 2026-11-18.
