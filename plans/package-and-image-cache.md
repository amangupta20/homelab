---
type: plan
status: "not started"
verified: "no (options read from their docs and source 2026-11-01; nothing installed or measured on the lab)"
tags:
  - plan
  - cache
  - docker
  - packages
---

# Package and image cache, redone

**Status:** not started. The candidate list was researched 2026-11-01; nothing
is installed, and the cache the lab has today has never been checked against
the live lab.
**Goal:** one cache on the home network answers apt and container-image
requests for every VM, stores what is asked for the first time, and keeps
itself inside a disk budget the owner chooses, so a redeploy stops coming down
from the internet again.
**Done when:** an `apt install` and a `docker pull` on a VM both show a miss
then a hit in the cache's own log, the cache volume has stayed under its
ceiling through a month of normal use, and `inventory/services.md` carries one
row for the new cache in place of the apt cache row.

## What exists today

- **apt cache** on the Docker + proxy host. Its port, how clients are pointed
  at it, and its state are that row's facts: `inventory/services.md`, where the
  State is "in docs, not verified". Nobody has confirmed what software it runs,
  how large its cache is, or whether clients actually use it.
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
   just because nobody re-pulled it this week.
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

Read from each project's own documentation and source on 2026-11-01. Nothing
below was installed or benchmarked; sizes and memory are the vendors' own
numbers unless marked.

| Candidate | Licence and shape | Caches | Eviction | Verdict |
|---|---|---|---|---|
| **Artifact Keeper** | MIT, Rust (Axum/SQLx), needs PostgreSQL 16 + OpenSearch, React UI | local + remote (pull-through) + virtual repositories; 40+ formats including Docker/OCI, Debian, RPM, npm, PyPI, Helm, raw | retention rules, promotion gates, per-run byte budgets; **no single size cap that evicts the oldest OCI blobs** | **Primary candidate.** Closest to requirements 1-5 and 7; heaviest of the real-OSS options |
| **NORA** | MIT, one Rust binary (~23 MB), no database, ~15 MB idle | 17 formats, Docker/OCI and Debian/apt among them (apt behind an opt-in flag) | **`proxy_cache_max_bytes`, a real size cap that evicts the oldest files** (currently Debian/RPM/Hugging Face), plus `keep_last` / `older_than_days` / tag-glob retention with a dry run | **Fallback, and the honest answer to requirement 4.** Small team and a young project; the byte cap does not cover OCI today |
| **Zot** | Apache-2.0, one Go binary, no database | OCI only; on-demand sync from several upstreams in one instance, dedupe, GC | TTL + GC + tag-count retention; **no access tracking, so no LRU** | Good engineering, wrong scope: no apt, no raw, no warmth reporting |
| **Harbor** | Apache-2.0 (CNCF), about 10 containers + PostgreSQL + Redis; 2 CPU / 4 GB / 40 GB minimum in its docs | OCI + Helm; one proxy-cache project per upstream | 7-day default retention per proxy project; quotas **block writes** rather than evict | Best UI (per-artifact pull counts, quota bars) but no apt and no raw, and the heaviest to run |
| **Nexus Community Edition** | **Proprietary EULA with usage caps** (40,000 components or 100,000 requests a day; over either, new components are refused). The EPL core on GitHub is source-only and cannot be built into the distributed binary | Docker, apt, raw, npm, PyPI and the rest | **cleanup policy on "last downloaded", the closest thing to on-demand LRU** | **Ruled out** on requirement 6, and on trust, despite fitting requirements 1-4 best |
| **Pulp** | GPLv2, PostgreSQL + Redis + workers | Debian, RPM, container (pull-through marked tech preview), PyPI, Ansible | GC, no size cap | Mature but heavy, and its container pull-through is not finished |
| **Artipie** | MIT, Java (Vert.x) | Maven, Docker, Debian, RPM and more | none documented | Its adapters have gone quiet; not a base to build on |
| **Gitea / Forgejo packages** | MIT / GPLv3 | hosted only, no pull-through proxy | not applicable | Fails requirement 1: a place to upload, not a cache |

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
next session does not redo it. All from its repository and documentation on
2026-11-01; **not deployed, and the audit is not finished**.

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
- **What the audit still has to settle:** the changelog for the 1.11.x line
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

## Steps

0. **Recon the cache that exists.** Read the apt cache's configuration on the
   Docker + proxy host, read-only: what software, what cache size, what
   retention, which VMs point at it, and how many requests a day it serves.
   Count the image pulls the homeserver makes in a week (`docker events`, or
   the registry's own view) so the size budget is chosen from a number. —
   gate: the software, the volume size and the pull count are written into
   this plan, and the apt cache row in `inventory/services.md` is corrected or
   confirmed.
1. **Finish the comparison.** Complete the security audit of Artifact Keeper
   (above), and price every candidate against the eight requirements in one
   table at the size step 0 implies. — gate: the table is in this plan with a
   recommendation, and each audit finding is fixed upstream, mitigated by
   configuration, or listed as accepted risk by the owner.
2. **The owner picks, and the budget is set.** One candidate, one volume size,
   one eviction rule (byte ceiling, retention window, or both), and where it
   runs: the Docker + proxy host, or its own VM. — gate: the choice and the
   numbers are written here, and the owner has approved the pull request that
   adds them.
3. **The stack goes into the repo.** `apps/homeserver/<name>/compose.yaml`
   plus its README, following `apps/README.md`; secrets and identifying values
   as references, never as values. — gate: merged, and `docker compose config`
   passes in CI.
4. **Prove it on one client before touching the rest.** Point one VM's apt at
   the new cache and one VM's Docker daemon at it. `registry-mirrors` covers
   Docker Hub only — Docker's own documentation states a daemon cannot point at
   a mirror of another upstream (read 2026-11-01) — so other registries need
   per-host mirror configuration instead. Pull an image twice and install a
   package twice. — gate: the cache's log shows one miss then a hit for
   each, and the same bytes are not fetched from the internet twice.
5. **Cut the fleet over, then retire the old cache.** Every VM's apt
   configuration and every Docker daemon, one at a time, with the old cache
   left running as the rollback until nothing has failed for two weeks. —
   gate: no VM has pointed at the old cache for two weeks; then it is
   stopped, its volume kept one more month, and its row in
   `inventory/services.md` is replaced.
6. **Measure it, and write down what it saves.** Hit rate, bytes served from
   disk against bytes fetched upstream, and `df` on the volume against the
   ceiling. — gate: a `journal/` entry, the numbers in `inventory/services.md`
   or a new `systems/` page, and the ceiling proved to hold over a month.

## Decisions this plan needs from the owner

- **Where it runs.** The Docker + proxy host already carries the reverse
  proxy, so the cache would share fate with the thing that routes traffic to
  it; a small VM of its own costs one more machine to patch and back up.
- **Whether apt stays with the current software.** If only images justify the
  work, the apt side can be left alone and this plan shrinks to steps 1, 3, 4
  and 6.
- **How much disk.** One number, chosen after step 0's pull count instead of
  guessed now.

## Links

`inventory/services.md` (the service list, and the apt cache row this
replaces), `inventory/hosts.md`, `inventory/network.md` (proxy host and
addresses), `apps/README.md` (what a stack page holds), `plans/README.md`,
`decisions/open-questions.md` ("Nothing verified yet", and the container
runtime question that decides where a homeserver stack is deployed from).
