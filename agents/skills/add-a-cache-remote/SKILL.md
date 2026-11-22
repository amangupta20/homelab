---
name: add-a-cache-remote
description: Use when a machine, stack or playbook starts pulling from an upstream the LAN cache does not know yet — an apt repository (a vendor's, or another distribution's archive), a container registry other than Docker Hub (ghcr.io, quay.io, lscr.io), or a new package format — so it is fetched through Artifact Keeper on cache-1 instead of straight from the internet. Adds the upstream to the cache's one list, sets a cap under the instance ceiling, creates it on cache-1 and checks one fetch.
---

# Add an upstream to the LAN cache

**Status:** UNTESTED as a whole. Each step ran on 2026-11-16 while the first five
upstreams were added, and steps 1, 3 and 4 again on 2026-11-17 for `raspi` and
`tailscale-apt` (`agents/journal/2026-11-16-deploy-artifact-keeper.md`).
**Touches:** writes to Artifact Keeper on `cache-1` (a new remote repository and its cap).

## When to use / when not to

Use it whenever something new on the LAN downloads from an upstream that is not a
line in `apps/homeserver/artifact-keeper/remotes.txt` (owner, 2026-11-16: the list
is kept by agents, not by hand). Typical moments:

- a stack in `apps/homeserver/` uses an image from a registry other than Docker Hub;
- a playbook or a VM adds an apt source (`deb …` line or `.sources` file);
- a tool is pointed at a new package format (PyPI, npm, Helm, …).

Not needed for Docker Hub images: every Docker daemon reaches them through
`registry-mirrors` without a new remote. Not for machines off the LAN (the VPS,
Oracle Cloud): the cache answers on the LAN only.

## Before you start

- Read `apps/homeserver/artifact-keeper/README.md` ("Repositories", "Quirks").
- No snapshot: a remote repository holds only a cache, and `cache-remotes.sh`
  recreates the settings (`agents/decisions/backup-tiers.md`, rebuildable state).

## Steps

1. **Pick the line.** In `apps/homeserver/artifact-keeper/remotes.txt` add
   `key  format  cap  upstream`:
   - `key`: short, lowercase, what clients will type (`quay`, `nodesource-apt`).
   - `format`: `docker` for any OCI registry, `debian` for any apt repository
     (Ubuntu's archives included), or the upstream project's name for another
     format (the backend's list is `RepositoryFormat` in its source).
   - `upstream`: the URL a client would use without the cache, `https://` as
     published. For apt, the folder that holds `dists/` and `pool/`.
   - `cap`: in GB, generous (owner, 2026-11-17): 15 for a vendor apt
     repository, 30 for an image registry, more for a distribution archive.
     The caps may add up to more than the disk; no single cap may exceed the
     instance ceiling, `STORAGE_QUOTA_BYTES` in `compose.yaml` (README, "How it
     stays inside the disk").
2. **Route the format if it is new.** `Caddyfile` passes each format's prefix
   to the backend and everything else to the web UI. A new format needs its prefix there (upstream's
   `docker/Caddyfile` lists them), then `ansible-playbook cache.yml` from
   `ansible/` — expect: the stack task reports changed.
3. **Create it.** `apps/homeserver/artifact-keeper/cache-remotes.sh` — expect:
   `<key>: created (200)` and `<key>: cap <n> GB (200)`; every other line says
   `exists`, and the last line says `cache-idle: updated, 30 days on <n>
   repositories`, with `<n>` the number of lines in `remotes.txt`. It stops if a
   cap is over the ceiling.
4. **Fetch through it twice** from `cache-1`:
   - apt: an `apt-get update` and `apt-get download <package>` with a
     throwaway configuration, as in the deploy journal entry, using
     `deb http://10.22.33.137/debian/<key> <suite> <component>`;
   - images: pull `10.22.33.137/<key>/<image>:<tag>` (a Docker daemon needs
     `10.22.33.137` in `insecure-registries`), or the registry API as in the
     journal entry.
5. **Tell clients.** Add a row to "Repositories" in the app's `README.md` with
   the line a client uses. Once the client playbook exists (plan step 4), it
   reads `remotes.txt`; until then, say in the pull request which machines
   should use the new remote.

## Verify

`GET /api/v1/repositories/<key>/proxy-cache-cap` with an admin token (password at
`kv/homelab/artifact-keeper`, user `admin`) shows non-zero `usage`, and the
second fetch is far faster than the first.

## Stop if

- the remote is created but every fetch answers 404 or HTML: the Caddyfile
  prefix is missing (step 2);
- the upstream needs a login (a private registry or a paid repository):
  credentials go in OpenBao and the remote needs upstream authentication, which
  this skill does not cover; ask the owner;
- the first fetch is very slow and the upstream is GitHub-hosted: that is the
  router's GitHub detour (`agents/decisions/open-questions.md`, "Home network"), not
  the cache.

## Afterwards

Commit `remotes.txt`, the README row (and the Caddyfile if changed) together, and
mention the test in the pull request. A journal entry only if the Caddyfile or
the stack changed.
