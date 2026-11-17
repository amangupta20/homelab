# Artifact Keeper on cache-1

The LAN's pull-through cache for apt packages and container images
(`plans/package-and-image-cache.md`). One Compose stack on its own VM, `cache-1`
(`iac/`), at `http://10.22.33.137` on the LAN only.

**Status:** running since 2026-11-16 (`journal/2026-11-16-deploy-artifact-keeper.md`).
No client points at it yet: that is the client playbook, plan step 4.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | backend, PostgreSQL (with TLS, as upstream), web UI and Caddy; trimmed from upstream's `docker-compose.yml` at commit `825b75e9` |
| `Caddyfile` | plain HTTP on port 80: the API, the registry (`/v2`) and the Debian format go to the backend, the rest to the web UI |
| `init-pg-ssl.sh` | upstream's script that turns on TLS in PostgreSQL at first start, unchanged |
| `remotes.txt` | the one list of remote repositories and their caps, read by `cache-remotes.sh` and, later, the client playbook; add one with `skills/add-a-cache-remote/` |
| `cache-remotes.sh` | creates the repositories in `remotes.txt` on cache-1, sets their caps and keeps the 30-day idle rule assigned to all of them; refuses a cap over the instance ceiling; safe to run again |

Deployed by `ansible/cache.yml`, which also writes the secret files from OpenBao
(`kv/homelab/artifact-keeper`: `db_password`, `jwt_secret`, `admin_password`). The
admin user is `admin`.

## Repositories

| Key | Upstream | Cap | How a client uses it |
|---|---|---|---|
| `dockerhub` | Docker Hub | 50 GB | `registry-mirrors` (no key in the path), or `10.22.33.137/dockerhub/<image>` |
| `ghcr` | ghcr.io | 30 GB | `10.22.33.137/ghcr/<owner>/<image>` |
| `debian` | `deb.debian.org/debian` | 40 GB | `deb http://10.22.33.137/debian/debian trixie main` |
| `debian-security` | `security.debian.org/debian-security` | 15 GB | `deb http://10.22.33.137/debian/debian-security trixie-security main` |
| `docker-apt` | `download.docker.com/linux/debian` | 15 GB | `deb [signed-by=<Docker's key>] http://10.22.33.137/debian/docker-apt trixie stable` |

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

## What it served

- **Hits and misses per repository:** `ak_proxy_cache_lookups_total` on
  `GET /api/v1/admin/metrics` (Prometheus format, admin token). `hit` is
  served from disk; `miss_no_metadata` is a file not cached yet and
  `miss_expired` one past its time to live, both fetched upstream; `miss`
  comes from a second lookup path the backend also counts (meanings read from
  `metrics_service.rs` and `proxy_service.rs`, not traced request by request).
  A counter, reset when the backend restarts.
- **Bytes served this month:** `ak_transfer_used_bytes` (kept in PostgreSQL,
  so it survives a restart; 563 MB on 2026-11-17).
- **Bytes stored:** `proxy_storage_bytes` on `GET /api/v1/admin/stats`, and
  each repository's size in the web UI.

Nothing reports bytes fetched from upstream, so "how much came from disk" is
read as hits against misses, not as bytes. Nothing scrapes the metrics yet.

## Deduplication

None across repositories with this storage backend. Files are stored per
repository (`proxy-cache/<repository>/<path>`), and the backend counts a file
present in two repositories as two (`storage_stats_service.rs`: on the
filesystem backend `shared_bytes` is always 0; only S3, GCS or Azure backends
share one copy). Within a repository a file is stored once. In practice the
remotes hold different upstreams, so the overlap is small: mostly base image
layers that exist on both Docker Hub and ghcr.io.

## Data

Bind mounts on the VM: `/srv/artifact-keeper/{postgres,storage,backups,plugins}`.
No backups by design: the files refill from upstream and the settings come back
from `cache-remotes.sh` (`decisions/backup-tiers.md`, rebuildable state).

## Quirks

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
  (`decisions/open-questions.md`). Later requests are served from disk.
