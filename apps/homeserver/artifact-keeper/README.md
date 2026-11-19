# Artifact Keeper on cache-1

The LAN's pull-through cache for apt packages and container images
(`agents/plans/package-and-image-cache.md`). One Compose stack on its own VM, `cache-1`
(`iac/`), at `http://10.22.33.137` on the LAN only.

**Status:** running since 2026-11-16 (`agents/journal/2026-11-16-deploy-artifact-keeper.md`).
Clients: `oob-1` (its own apt sources) and every VM in the inventory's `lan_cache_clients`
group (`ansible/cache-client.yml`, from 2026-11-18; `proxy-1` first).

## Repositories

| Key | Upstream | Cap | How a client uses it |
|---|---|---|---|
| `dockerhub` | Docker Hub | 50 GB | `registry-mirrors` (no key in the path), or `10.22.33.137/dockerhub/<image>` |
| `ghcr` | ghcr.io | 30 GB | `10.22.33.137/ghcr/<owner>/<image>` |
| `debian` | `deb.debian.org/debian` | 40 GB | `deb http://10.22.33.137/debian/debian trixie main` |
| `debian-security` | `security.debian.org/debian-security` | 15 GB | `deb http://10.22.33.137/debian/debian-security trixie-security main` |
| `docker-apt` | `download.docker.com/linux/debian` | 15 GB | `deb [signed-by=<Docker's key>] http://10.22.33.137/debian/docker-apt trixie stable` |
| `raspi` | `archive.raspberrypi.com/debian` | 15 GB | `deb http://10.22.33.137/debian/raspi trixie main` (used by `oob-1`) |
| `tailscale-apt` | `pkgs.tailscale.com/stable/debian` | 15 GB | `deb [signed-by=<Tailscale's key>] http://10.22.33.137/debian/tailscale-apt trixie main` (used by `oob-1`) |

Clients today: `oob-1`, through `ansible/oob.yml` (2026-11-17); `proxy-1`, apt and the
Docker Hub mirror, through `ansible/cache-client.yml` (2026-11-18).

## Data

Bind mounts on the VM: `/srv/artifact-keeper/{postgres,storage,backups,plugins}`.
No backups by design: the files refill from upstream and the settings come back
from `cache-remotes.sh` (`agents/decisions/backup-tiers.md`, rebuildable state).

Everything else, word for word, is in `NOTES.md`: "Files", "Sign-in", "How it stays
inside the disk", "Dashboard", "Deduplication", "Quirks".
