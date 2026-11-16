# 2026-11-16 — Artifact Keeper deployed on cache-1 and tested

**Who:** Claude Code, at the owner's request  **Scope:** VM `cache-1`  **Mode:** write
**Task:** `plans/package-and-image-cache.md` steps 2 and 3  **Skill:** none

## What changed

- Three secrets generated into OpenBao, `kv/homelab/artifact-keeper` (`db_password`, `jwt_secret`, `admin_password`).
- `ansible/cache.yml` installed Debian's Docker 26.1.5 and Compose 2.26.1, made the bind-mount folders under
  `/srv/artifact-keeper`, copied `apps/homeserver/artifact-keeper/` to `/opt/artifact-keeper` with the secret files,
  and started the stack: PostgreSQL 18 (TLS on), the backend (`main`, digest `9cacff07…`, reporting 1.12.0), the web UI
  1.11.2 and Caddy on port 80.
- `cache-remotes.sh` created five public remote repositories with caps adding up to 80 GB: `dockerhub` 40, `ghcr` 10,
  `debian` 14, `debian-security` 6, `docker-apt` 10. A second run changed nothing.
- A throwaway repository `captest` was created for the cap test and deleted afterwards (404 after deletion).

## Snapshot / backup taken

None: a new stack on a new VM, and the cache VM has no backups by the owner's decision (`decisions/backup-tiers.md`).

## How it was verified

- `docker compose ps`: all four services up, the backend healthy; `/health` reports database and storage healthy;
  `show ssl` in PostgreSQL is `on`; the backend logged "Admin user created with password from ADMIN_PASSWORD env var".
  The whole VM used 577 MB of memory with the stack running.
- **apt as the client**, with a throwaway configuration in `/tmp` (download only, nothing installed): `apt-get update`
  against `debian`, `debian-security` and `docker-apt` verified every `InRelease` without a warning; `apt-get download
  hello docker-ce-cli` worked. The cache then held the indexes and both packages (usage counters 16.4 MB and 8.7 MB),
  and a direct fetch of `docker-ce-cli` (8.6 MB) from it took 0.06–0.08 s, `hello` 0.01 s.
- **Images**, through the registry API with anonymous tokens as a Docker client does: `dockerhub/library/alpine:3.20`
  4.13 s then 0.12 s; `library/busybox:1.37` with no repository key (the `registry-mirrors` path) 3.29 s then 0.08 s;
  a 52 MB `ghcr/aquasecurity/trivy` layer 0.17 s once cached.
- **Cap:** `captest` (Docker Hub, 4 MB cap) after three images logged "evicted least recently used entries …
  entries=4 bytes=3641182" (the `alpine` image) and sat at 2.2 MB, under its cap.

## Still open

- **ghcr.io first fetches are slow from the LAN.** One `trivy` layer broke partway; the backend closed the client's
  connection and cached nothing ("upstream body failed after the response had started … nothing cached"), and a later
  request filled it. The slowness is the router forwarding LAN traffic into its GitHub detour, not the cache
  (`decisions/open-questions.md`, "Home network").
- No client points at the cache yet (plan step 4).
