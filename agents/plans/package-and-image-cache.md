---
type: plan
tags:
  - plan
  - cache
  - docker
  - packages
---

# Package and image cache, redone

**Status:** in progress. The candidate list was researched 2026-11-01 and
again on 2026-11-15, when Artifact Keeper was also run on the workstation (see
"Local test"). On 2026-11-16 the owner picked Artifact Keeper for a trial of at
least a month, replacing apt-cacher-ng, and dropped the recon of the old
cache (see "Steps"). Running on `cache-1` since 2026-11-16; step 4, the
clients, is mostly done.
**Goal:** one cache on the home network answers apt and container-image
requests for every VM, stores what is asked for the first time, and keeps
itself inside a disk budget the owner chooses, so a redeploy stops coming down
from the internet again.
**Done when:** an `apt install` and a `docker pull` on a VM both show a miss
then a hit in the cache's own log, the cache volume has stayed under its
ceiling through a month of normal use, and `inventory/services.md` carries one
row for the new cache in place of the apt cache row.

## What exists today

- **apt cache** on the VM `apt-cache` (apt-cacher-ng on port 3142, no Docker),
  verified by SSH 2026-11-14: `inventory/services.md` and `inventory/hosts.md`
  now agree on it. Nobody has confirmed how large its cache is or whether
  clients actually use it.
- **No image cache.** Every `docker pull` on every VM goes to the internet
  registry named in the compose file. The homeserver runs most stacks on
  `latest` and redeploys them, so the same base images come down again and
  again (owner's description of the lab, 2026-11-01; no byte count measured).

## Why it is being redone

1. **A URL-caching proxy cannot cache an HTTPS repository.** Docker's apt
   repository answers a plain-HTTP request with a redirect to HTTPS. Run
   2026-11-01:
   `curl -sS -o /dev/null -D - http://download.docker.com/linux/ubuntu/dists/noble/InRelease`
   returns `HTTP/1.1 301 Moved Permanently` and
   `Location: https://download.docker.com/...`. A proxy that caches by URL can
   cache nothing from that repository: the URL it is asked for answers with an
   instruction to fetch elsewhere, over TLS. The same shape is common among the
   vendor repositories that add packages to these VMs, though each was not
   checked individually.
2. **Images, not packages, are the weight.** One base image is hundreds of
   megabytes; the packages a VM installs are orders of magnitude smaller. The
   cache that pays for itself is the image one.
3. **A cache with no ceiling is not usable on one server.** Left alone, either
   cache grows until the volume fills, and a full volume is how a registry
   loses its own database. The cache has to be told a size and evict down to
   it.

## What the owner needs, in order

Said by the owner in conversation on 2026-11-15:

1. **apt caching is required.**
2. **apt from HTTPS-only repositories** is wanted strongly.
3. **Container images** are wanted, but are not a hard requirement.
4. **More formats later** (not named yet) should be possible without
   replacing the cache.

This reorders "Why it is being redone" below, which was written on 2026-11-01
with images as the main payoff.

## What the cache has to do

These are requirements, not features of any one product; the step-1 comparison
scores candidates against them.

1. **Cache on first use.** No pre-seeding list to maintain: the first request
   stores the artifact, later requests are served from disk.
2. **More than one upstream registry.** Images come from Docker Hub, `ghcr.io`
   and a few vendor registries, so the cache must proxy several upstreams, not
   one.
3. **apt over HTTPS.** Vendor repositories must be cacheable even though the
   upstream speaks TLS.
4. **A disk ceiling with eviction by use.** When the volume reaches the
   ceiling, the least recently used artifacts go first — not "expire
   everything older than N days", which evicts an image the lab deploys daily
   just because nobody re-pulled it this week. A ceiling per upstream
   repository meets this; one ceiling across everything would be better, and
   no multi-format candidate has it (worker research, 2026-11-15, read from
   docs and source).
5. **Visible warmth.** Per-repository size and hit counts, in a UI or a
   metric, so the owner can see what the cache is spending disk on. The owner
   liked this about the cache that exists today (his description, 2026-11-01;
   unverified, since that software has not been identified yet — see the first
   bullet above).
6. **No licence cap that a homelab can hit.** The cache must not stop adding
   content because a component counter went over a vendor's free-tier limit.
7. **Survivable when full.** If the volume does fill, it must fail a write,
   not corrupt metadata, and it must not depend on a database that a full disk
   can take down.
8. **Buildable on one VM.** A Compose stack, with no external services it does
   not ship itself.

## Candidates

Read from each project's own documentation and source on 2026-11-01, and
again on 2026-11-15 by two research worker agents whose claims were not
re-checked unless a row says "tested". Only Artifact Keeper was run; sizes and
memory are the vendors' own numbers unless marked.

| Candidate | Licence and shape | Caches | Eviction | Verdict |
|---|---|---|---|---|
| **Artifact Keeper** | MIT, Rust (Axum/SQLx), needs PostgreSQL; OpenSearch and the scanners are optional (tested 2026-11-15), React UI | local + remote (pull-through) + virtual repositories; 40+ formats including Docker/OCI, Debian, RPM, npm, PyPI, Helm, raw | retention rules by age or last download; **a byte cap per remote repository that evicts the least recently used entries, in 1.12.0** (tested 2026-11-15 on the `main` image; the `latest` image that day was 1.11.13, without it). No one cap across all repositories | **Primary candidate.** Meets requirements 1-5 in the local test; young, fast-moving, mostly one author |
| **NORA** | MIT, one Rust binary (~23 MB), no database, ~15 MB idle | 17 formats, Docker/OCI and Debian/apt among them (apt behind an opt-in flag) | **`proxy_cache_max_bytes`, a real size cap that evicts the oldest files** (currently Debian/RPM/Hugging Face), plus `keep_last` / `older_than_days` / tag-glob retention with a dry run | **The one to compare against.** Simplest to run, and its byte cap covers apt, the owner's required part. Small team and a young project; the byte cap still does not cover OCI (worker reading of its source, 2026-11-15); not run here |
| **Zot** | Apache-2.0, one Go binary, no database | OCI only; on-demand sync from several upstreams in one instance, dedupe, GC | TTL + GC + tag-count retention; **no access tracking, so no LRU** | Good engineering, wrong scope: no apt, no raw, no warmth reporting |
| **Harbor** | Apache-2.0 (CNCF), about 10 containers + PostgreSQL + Redis; 2 CPU / 4 GB / 40 GB minimum in its docs | OCI + Helm; one proxy-cache project per upstream | 7-day default retention per proxy project; quotas **block writes** rather than evict | Best UI (per-artifact pull counts, quota bars) but no apt and no raw, and the heaviest to run |
| **Nexus Community Edition** | **Proprietary EULA with usage caps** (40,000 components or 100,000 requests a day; over either, new components are refused). The EPL core on GitHub is source-only and cannot be built into the distributed binary | Docker, apt, raw, npm, PyPI and the rest | **cleanup policy on "last downloaded", the closest thing to on-demand LRU** | **Ruled out** on requirement 6, and on trust, despite fitting requirements 1-4 best |
| **Pulp** | GPLv2, PostgreSQL + Redis + workers | Debian, RPM, container (pull-through marked tech preview), PyPI, Ansible | GC, no size cap | Mature but heavy, and its container pull-through is not finished |
| **Artipie** | MIT, Java (Vert.x) | Maven, Docker, Debian, RPM and more | none documented | Its adapters have gone quiet; not a base to build on |
| **Gitea / Forgejo packages** | MIT / GPLv3 | hosted only, no pull-through proxy | not applicable | Fails requirement 1: a place to upload, not a cache |
| **rpardini/docker-registry-proxy** | Apache-2.0, nginx in one container | container images from every registry, as an intercepting HTTPS proxy; no apt | **byte ceiling with nginx's least-recently-used eviction** (`CACHE_MAX_SIZE`) | Images-only fallback. Every client must trust its certificate authority; no UI and no per-repository sizes (worker research 2026-11-15, not run) |
| **nginx caching proxy** | BSD, one process | anything over HTTP(S), with a configuration block per upstream | **byte ceiling with least-recently-used eviction** (`proxy_cache_path ... max_size`) | Smallest way to cache HTTPS apt inside a ceiling; no UI, hand-written configuration, a dead end for more formats (worker research 2026-11-15, not run) |
| **apt-cacher-ng, kept** | the software `inventory/hosts.md` records on the `apt-cache` VM | apt only; an HTTPS upstream is cached through a `Remap-` rule per repository or a `http://HTTPS///host/...` source line on the client, not through `PassThroughPattern` | expiry only, no byte ceiling | The do-nothing option: covers apt and HTTPS apt, nothing else (worker research 2026-11-15, from its documentation; **UNTESTED** here) |

### Why Nexus is ruled out

The free download is called "Community Edition" and reads like open source,
but the licence governing the binary is a proprietary EULA carrying a hard
usage cap, and the EPL source Sonatype publishes is deliberately incomplete.
The project's own community forum records a developer who fixed an apt bug in
that source and could not run the fix, because the shipped image carries
non-free components. For a homelab whose point is that it can be rebuilt from
code, a cache that stops accepting content when a vendor counter passes a
threshold is a dependency to avoid. Source: Sonatype's release notes, tiers
page and community forum, read 2026-11-01.

## What is known about Artifact Keeper so far

The owner's starting position is Artifact Keeper as the primary candidate, so
its source got a first pass before this plan was written. Recorded here so the
next session does not redo it. The bullets below are from its repository and
documentation on 2026-11-01; the local test and the two source reviews that
follow are from 2026-11-15. **Not deployed on the lab.**

- **Licence:** MIT, copyright Brandon Geraci. The whole feature set ships in
  one release, with no paid edition and no usage cap.
- **Shape:** Rust backend (Axum, SQLx, Tokio), React front end, PostgreSQL 16
  for metadata, OpenSearch for search, artifacts on the filesystem or in S3,
  content-addressed by SHA-256 with deduplication. Trivy, Grype and OpenSCAP
  run as sidecars; Dependency-Track is an opt-in profile that the project's
  own compose file warns costs about 4 GiB of RAM while idle.
- **Caching model:** three repository types — local (uploaded), remote
  (pull-through, revalidated after a TTL), and virtual (local then remote
  behind one URL, in priority order). Its documentation describes the remote
  type as caching on the first request.
- **Hardening already present:** `JWT_SECRET` has no default and placeholder
  values are refused; the admin password is generated at first boot and weak
  values abort startup; a setup guard blocks mutations until that password is
  changed; the runtime image is UBI 9, non-root, with no shell; PostgreSQL is
  reached over TLS and published on loopback only; releases have been
  cosign-signed with build provenance and a CycloneDX SBOM since 1.8.2; and a
  red-team suite covering CORS, auth bypass, default credentials, path
  traversal and plugin installs lives in the repository.
- **What the audit had to settle (answered under "Source reviews" below):** the changelog for the 1.11.x line
  records a run of published authorization advisories — a read-only token able
  to change scan configuration, missing action-level checks on mutation
  handlers, a read-only member able to delete SBOM attestations, an
  authenticated user able to install an arbitrary WASM plugin. Every one is
  fixed in the release that ships it and disclosure was handled properly, but
  the rate of that class of bug is the biggest open question about putting it
  in front of the lab. The audit reads the advisory list, the authorization
  middleware and the plugin path, and answers whether it is safe on the LAN
  behind the owner's admin path only.

Worth knowing before sizing it: the shipped `docker-compose.yml` calls itself
a starting point for evaluation, not production. It sets
`ENVIRONMENT=development`, hardcodes the PostgreSQL credentials and turns on
`ALLOW_HTTP_INTEGRATIONS`. Anything deployed from it is re-configured first.

### Local test, 2026-11-15

Run on the owner's workstation, published on loopback only, then removed with
its volumes and images. The stack was the project's `docker-compose.yml` cut
down to four containers: backend, PostgreSQL, web UI and Caddy. The `main`
image was used because the released one had no byte cap; it reported version
1.12.0 on `/health`.

| Check | Result |
|---|---|
| Memory, four containers idle (`docker stats`) | about 185 MB |
| `docker pull` of a small image through a Docker Hub remote, twice | 3.5 s, then 0.3 s |
| 30 MiB cap on that remote (`PUT /api/v1/repositories/<key>/proxy-cache-cap`), then three more images | the fourth pull evicted the 19 oldest entries (26.8 MB); the backend logged the eviction and usage stayed under the cap |
| Pull without the repository key in the path, with `AK_DEFAULT_DOCKER_MIRROR_REPO` set (what Docker's `registry-mirrors` sends) | worked |
| A 674 MB image through a `ghcr.io` remote, under a prefixed name | worked |
| apt remote on `https://download.docker.com/linux/ubuntu`: `InRelease`, `Packages.gz` and a 17.6 MB package with `curl`, twice each | package 4.1 s, then 0.07 s |
| Requests with no credentials | user and admin routes answer 401; the repository list answers 200 |

What the test did not cover: a full Ubuntu or Debian archive as an apt remote,
`apt` itself as the client (the files were fetched with `curl`), a full disk,
an upgrade between versions, and the released 1.12.0 image, which did not
exist yet. PostgreSQL ran without TLS in the test because the init container
could not reach its package mirror that evening; the real stack keeps TLS.

### What the trimmed stack leaves out

| Left out | What it provides | Cost of leaving it out |
|---|---|---|
| OpenSearch | full-text search over artifacts in the UI and API | none for a cache that is pulled by name; saves its 512 MB heap |
| Trivy, OpenSCAP | vulnerability and compliance scans of stored artifacts | no scan results |
| Dependency-Track | tracking of software bills of materials over time | none; it is already off by default upstream, which measures it at about 4 GiB idle |

The backend starts without them when `OPENSEARCH_URL`, `TRIVY_URL` and
`OPENSCAP_URL` are unset (tested). Unused but still present in the backend:
hosted and virtual repositories, promotion gates, replication between
instances, WASM plugins, webhooks, single sign-on and the other formats.

### What PostgreSQL holds

Read from the test instance with `psql`: 188 tables, 21 MB after the test,
against 692 MB of cached files on the storage volume. The database holds the
cache catalogue (path, size, SHA-256, upstream URL, when cached and when last
read, which is what eviction orders by), which image manifests reference which
layers, the repositories and their settings, users and tokens, download
counts and the audit log. The file bytes are on disk, not in the database. A
cache that loses its database loses the catalogue and refills on first use.

### Source reviews

Two worker agents each reviewed the repository at commit `2ca1c3f`
(2026-11-15) against the same eight questions, without running it. Both
answered "safe and sensible on a LAN, with conditions". Their claims are
theirs; the ones marked tested were confirmed in the local test.

- **Unauthenticated access.** Anonymous read is on by default and applies to
  repositories marked `public`; writes and admin routes always need a
  credential. For a cache, only the cache remotes are made `public`.
- **Authorization.** The changelog from July to November 2026 carries a dense
  run of fixed authorization advisories. There is now one central guard, but
  each handler has to call it, so a new route can forget. One reviewer sampled
  mutation handlers and found none without the check; neither swept all of
  them.
- **Disk.** The cap is per remote repository (tested). Writes go to a temporary
  file and are renamed, so a full disk should fail a write without damaging
  the catalogue; nobody tested that.
- **Project.** About ten months old, roughly 80% of commits from one author,
  several builds a day.
- **Docker clients.** `registry-mirrors` reaches Docker Hub only (the mirror
  path itself was tested);
  other registries need the cache's host and repository key in the image name
  or per-host client configuration.

Conditions both reviewers set: a byte cap on every remote from the first day,
LAN only with only the cache remotes public, and a pinned release with a VM
snapshot before each upgrade.

## Steps

The recon of the old apt cache and the week's pull count, step 0 until
2026-11-16, were dropped by the owner: every VM is recreated from code in
`agents/plans/home-overhaul.md`, so no old VM is moved over to the new cache, and
the lab has been offline and unmaintained for a while, so a week's pulls
would not have measured normal use.

1. **The owner accepts the review conditions and sets the budget.** The
   conditions from "Source reviews": a byte cap on every remote from the
   first day, LAN only with only the cache remotes public, and a pinned image
   with a VM snapshot before each upgrade. The budget is set (owner,
   2026-11-16; "Decisions" below). **Done 2026-11-16:** the owner accepted
   the conditions; it is LAN only, open to every machine on the LAN, with its
   data on a bind mount on the VM. — gate: written in "Decisions" below.
2. **The stack goes into the repo.** `apps/homeserver/<name>/compose.yaml`
   plus its README, following `apps/README.md`; secrets and identifying values
   as references, never as values. The backend image is `main`, pinned by
   digest, and the README says why and when it moves to a release (see
   "Decisions"). The remotes and their caps are created by a script in the
   same folder, through the API the local test used, so a lost VM is rebuilt
   from the repo instead of a backup. — gate: merged, and `docker compose
   config` passes in CI. Written 2026-11-16 (`apps/homeserver/artifact-keeper/`,
   deployed by `ansible/cache.yml`); the gate waits for the merge.
3. **Its own VM, built from code, and proved there.** The VM is the first one
   of `agents/plans/home-overhaul.md`'s step B. On it, check what the local test did
   not: a full Ubuntu or Debian archive as an apt remote with `apt` itself as
   the client, a vendor HTTPS apt repository, `docker pull` through Docker
   Hub and one other registry, and a remote filled past its cap.
   `registry-mirrors` covers Docker Hub only — Docker's own documentation
   states a daemon cannot point at a mirror of another upstream (read
   2026-11-01) — so other registries need per-host mirror configuration
   instead. Only after this passes is the digest written into the compose
   file as the verified one. — gate: the cache's log shows one miss then a
   hit for each, usage stays under the cap, and a `agents/journal/` entry records it.
   **Done 2026-11-16** (`agents/journal/2026-11-16-deploy-artifact-keeper.md`): apt as
   the client against the full Debian archive, the security archive and
   Docker's apt repository; images from Docker Hub (by key and by the mirror
   path), ghcr.io and Docker Hub again past a 4 MB test cap, which evicted the
   least recently used image. Misses and hits are read from the cache's usage
   counters and timings; the backend logs a miss outright only on a failure.
   The pinned digest in `compose.yaml` is now the verified one. Found on the
   way: first fetches from ghcr.io are slow from the LAN (the README's
   "Quirks").
4. **New VMs use it from the start, through one Ansible role.** The role
   writes each client's apt sources and Docker `daemon.json` mirror, and runs
   on every VM built from code, and on machines that are not (the
   workstation, a laptop). The cache's address is one variable in the role.
   One switch in the role points clients back at the upstream repositories,
   so if the cache goes wrong, a rerun of the role takes the LAN off it. Old
   VMs are not reconfigured; apt-cacher-ng goes when its VM, `.254`, is
   dropped with the rest. — gate: the role is in the repo, a test VM is
   switched to upstream and back with it, and `inventory/services.md` has the
   new cache's row in place of the apt cache row once `.254` is gone.
   **Mostly done 2026-11-18:** `ansible/cache-client.yml` (a playbook, not a
   role), on every host in the inventory's `lan_cache_clients` group, which a
   commit check makes every home VM join or be exempted from
   (`ansible/README.md`, "Adding a host"). It lists cache-1 first and Debian's
   own mirror second, so apt falls back by itself, and Docker falls back to
   Docker Hub. On `proxy-1`, `lan_cache=""` switched it to upstream (apt
   fetched nothing from cache-1) and a rerun switched it back (apt lists and a
   `docker pull` through cache-1). Not done: the workstation and laptops, and
   the apt cache row, which waits for `.254`.
5. **The month's trial, measured.** At least a month of normal use after step
   3: hit rate, bytes served from disk against bytes fetched upstream, `df`
   on the volume against the cap, idle memory, and every manual clean-up.
   The cache's dashboard collects all but the clean-ups since 2026-11-17
   (`apps/homeserver/artifact-keeper/README.md`, "Dashboard").
   — gate: the numbers in a `agents/journal/` entry and in `inventory/services.md`
   or a new `systems/` page, and the owner's keep-or-change decision written
   in "Decisions".
6. **Move from `main` to a release.** When a release carries the per-remote
   byte cap (1.12.0, or whichever release first includes the `main` build
   that was verified), snapshot the VM and switch the pinned image to that
   release. — gate: the cap still evicts after the switch, and the compose
   file names a release instead of `main`.

## Decisions this plan needs from the owner

- **Where it runs.** Decided by the owner on 2026-11-15: **its own VM**, built
  from code as the first VM of `agents/plans/home-overhaul.md`'s step B, before the
  agent VM. (The alternative was the Docker + proxy host, which would have
  made it share fate with the reverse proxy.)
- **Whether apt stays with the current software.** Answered by the owner's
  order of needs (2026-11-15): apt is the required part, so it moves to the new
  cache. On 2026-11-16 the owner set how: new VMs use the new cache from the
  start, and apt-cacher-ng is dropped with the old VMs instead of running
  beside it as a rollback.
- **Which candidate.** Decided by the owner on 2026-11-16: **Artifact
  Keeper**, replacing apt-cacher-ng, on a trial of at least a month. If it
  works well it stays; if not, it is changed for another candidate. What
  "works well" means is not written down yet; a number (idle memory, or
  manual clean-ups in the month) would make the end of the trial checkable.
- **Which image.** Decided by the owner on 2026-11-16: **`main`, once
  verified on the cache VM (step 3)**, pinned by digest. Why: the per-remote
  byte cap is the owner's way of keeping the cache inside its budget, and on
  2026-11-15 it was only in `main` (the `latest` release was 1.11.13,
  without it). The cache moves to a release as soon as one ships the cap or
  the verified `main` (step 6). The cost: `main` builds several times a day
  and has had no release testing, so the pinned digest is only changed with a
  VM snapshot first.
- **How much disk.** Decided by the owner on 2026-11-16, as a starting
  point, not measured (the lab has been offline): a **100 GB** VM disk (the
  owner said 60-100 GB; 100 is the size that fits the cap plus the system and
  PostgreSQL), and **80 GB of cache**. Artifact Keeper has no single cap
  across repositories (see "Candidates"). On 2026-11-16 the 80 GB was the sum
  of the per-remote caps. **Changed by the owner on 2026-11-17:** the 80 GB is
  an instance-wide ceiling (which stops storing, not evicts), the per-remote
  caps are generous (Docker Hub 50 GB) and add up to more, and a 30-day idle
  rule, keyed on last serve, drains what nobody fetches
  (`apps/homeserver/artifact-keeper/README.md`, "How it stays inside the
  disk").
- **Operating system.** Debian 13, like every home VM built from code
  (`agents/plans/home-overhaul.md`, "One operating system"; owner, 2026-11-16).
- **How clients find it.** Decided by the owner on 2026-11-16: the cache
  VM's fixed address is set on the VM itself, in its OpenTofu and cloud-init
  configuration, not by a DHCP reservation or DNS entry on the OpenWrt router,
  and clients get it from the Ansible role in step 4. Router-side tricks were
  weighed and left out: proxy auto-discovery does not fit (Artifact Keeper is
  addressed by repository URL, not as a proxy), intercepting HTTPS needs a
  certificate on every client, and answering `archive.ubuntu.com` with the
  cache's address would break every apt client on the LAN whenever the cache
  is down. The address is `.137` (`inventory/network.md`, chosen 2026-11-16).
- **Backups.** Decided by the owner on 2026-11-16: **no automatic backups**
  of the cache VM, so it does not fill backup space with cached packages. A
  manual VM snapshot before an upgrade, when needed; if the cache breaks, it
  is cleared and refills from upstream. What is lost with the VM is the
  remotes, caps and users in PostgreSQL, which step 2's script recreates.
  It falls under the rebuildable-state exemption in
  `agents/decisions/backup-tiers.md` (owner, 2026-11-16).

## Links

`inventory/services.md` (the service list, and the apt cache row this
replaces), `inventory/hosts.md`, `inventory/network.md` (proxy host and
addresses), `apps/README.md` (what a stack page holds), `agents/plans/README.md`,
`agents/decisions/open-questions.md` ("Nothing verified yet", and the container
runtime question that decides where a homeserver stack is deployed from).
