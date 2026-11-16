# Artifact Keeper on cache-1

The LAN's pull-through cache for apt packages and container images
(`plans/package-and-image-cache.md`). One Compose stack on its own VM, `cache-1`
(`iac/cache-vm.tf`), at `http://10.22.33.137` on the LAN only.

**Status:** running since 2026-11-16 (`journal/2026-11-16-deploy-artifact-keeper.md`).
No client points at it yet: that is the client playbook, plan step 4.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | backend, PostgreSQL (with TLS, as upstream), web UI and Caddy; trimmed from upstream's `docker-compose.yml` at commit `825b75e9` |
| `Caddyfile` | plain HTTP on port 80: the API, the registry (`/v2`) and the Debian format go to the backend, the rest to the web UI |
| `init-pg-ssl.sh` | upstream's script that turns on TLS in PostgreSQL at first start, unchanged |
| `cache-remotes.sh` | creates the remote repositories and their caps; safe to run again |

Deployed by `ansible/cache.yml`, which also writes the secret files from OpenBao
(`kv/homelab/artifact-keeper`: `db_password`, `jwt_secret`, `admin_password`). The
admin user is `admin`.

## Repositories

| Key | Upstream | Cap | How a client uses it |
|---|---|---|---|
| `dockerhub` | Docker Hub | 40 GB | `registry-mirrors` (no key in the path), or `10.22.33.137/dockerhub/<image>` |
| `ghcr` | ghcr.io | 10 GB | `10.22.33.137/ghcr/<owner>/<image>` |
| `debian` | `deb.debian.org/debian` | 14 GB | `deb http://10.22.33.137/debian/debian trixie main` |
| `debian-security` | `security.debian.org/debian-security` | 6 GB | `deb http://10.22.33.137/debian/debian-security trixie-security main` |
| `docker-apt` | `download.docker.com/linux/debian` | 10 GB | `deb [signed-by=<Docker's key>] http://10.22.33.137/debian/docker-apt trixie stable` |

The caps add up to 80 GB (10^9 bytes) on a 100 GB disk (owner, 2026-11-16). Each
cap evicts its own repository's least recently used entries; there is no cap
across all of them. Read one with `GET /api/v1/repositories/<key>/proxy-cache-cap`
(admin token).

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
