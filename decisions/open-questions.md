# Open questions

Everything undecided, or written down but never checked against the live lab.
One list, so nothing hides in a section of some other page.

Agents append here when they find a contradiction or a claim they cannot
verify — and stop there, rather than picking a side. Only the owner resolves an
item; when resolved, it becomes a decision in this folder or a fact in its
owner file, and is deleted from this list.

## Nothing verified yet

- The docs were written from memory, not from an audit. Every service, host,
  schedule and retention setting is unconfirmed until the read-only recon pass
  compares it to the live lab.

## Platform (XCP-ng, Xen Orchestra)

- Do the live XO backup schedules and retention match `systems/backups.md`?

## Backups

- Where does the offsite copy land, and is it encrypted at rest?
- Does OpenBao's backup travel the same offsite path or need its own?
- Proposal 2026-10-31 for the two items above: `decisions/backup-tiers.md`
  (encrypted B2 tier sent from the source, OpenBao first). Also open with it:
  which services besides OpenBao get that tier, and where the offsite
  encryption keys are kept outside the lab.

## Provisioning (`iac/`)

- "Reproducible from code" and "`vm.tf` is git-ignored so local names never
  leak" cannot both be true. A rebuildable lab needs VM definitions committed
  with only secrets kept out. Which names are actually sensitive in a public
  repo?
- Ansible: the README named it as the after-boot configuration tool, but the
  repo has no playbooks. Is it still the plan?
- cloud-init: one committed template per VM, or generated?

## Secrets (OpenBao)

- Auto-unseal: undecided. Without it, every restart needs a human with the keys.
- Swap: the VPS has an 8 GB swap file in use (recon 2026-10-26), and
  OpenBao 2.7.1 rejects `disable_mlock` as an unknown field (local test
  2026-10-26); whether it locks its memory at all is unverified, so secrets
  may be written to swap. OpenBao's install page advises keeping it out of swap. Turn swap
  off on the VPS, accept it, or use encrypted swap?
- Delivery to homeserver containers: a sidecar writing `/run/secrets` is the
  working assumption; a container manager with native vault support would
  replace it.

## Container runtime (homeserver)

- Portainer replacement: Arcane is the likely candidate, Komodo the
  alternative. Nothing chosen or tested.
- Does the chosen manager read OpenBao natively?
- Which of the three-year-old stacks are worth migrating, and which get retired?

## Remote VPS (Dokploy)

- How Dokploy deploys from this repo, and whether it keeps its own copy of
  each stack.
  Answered for one app, 2026-10-27: from git, branch `main`, compose path
  `apps/vps/hermes-webui/compose.yaml`, no copy kept — a merged change reached
  the container only when the service was deployed by hand (auto-deploy off).
- Which apps run on it — listed by the recon on 2026-10-26 in
  `inventory/services.md`; for the owner to close.
- Contradiction, found 2026-10-27 while updating the app lists: `apps/README.md`
  and `apps/vps/README.md` both call OpenBao "defined, not deployed", while
  `inventory/services.md` says it is "running, unsealed — verified 2026-10-26"
  and `journal/2026-10-26-install-openbao.md` records the install. Which is
  current?
  Answered 2026-10-27, on the owner's instruction: OpenBao is deployed. Dokploy
  read the second Hermes WebUI's password out of `kv/dokploy/hermes-webui` at
  deploy time that day, which neither a stopped OpenBao nor an absent one can
  do, so the two `apps/` READMEs were the stale side and now say deployed. The
  item stays here for the owner to close.
- Found by the step-0 recon (2026-10-26, `systems/vps.md`):
  - The `odysseus` backup always fails and the `Odyssues` project has no
    containers (`systems/backups.md`, `inventory/services.md`). Retire the
    app, or fix the backup?
  - Several apps have no running containers (`inventory/services.md`, "Apps
    on the VPS"). Still wanted, or retire?
  - The owner says the Dokploy dashboard's domain is not proxied by
    Cloudflare; a request to it on 2026-10-26 got a response with the header
    `server: cloudflare`. Which is current?

## Foundations

- SSO: which one. Per the owner (2026-10-26), Authentik was tried around 2024 and found too heavy, but
  that was early in learning self-hosting, so dropping it is not final.
  Lighter candidates (Authelia, Pocket ID, Kanidm) have not been compared.

## Not planned yet

- Observability: wanted, not deployed. Prometheus/Grafana is an assumption,
  not a choice. Whether Uptime Kuma runs at all is unknown
  (`inventory/services.md`).

## Reverse proxy (home edge and VPS)

- Which proxy owns the home edge — stay on Nginx Proxy Manager, put a small
  Caddy behind it for wakeable hosts, or replace it with Caddy or Traefik? Only
  matters if on-demand wakeups are adopted (`ideas/on-demand-container-wakeups.md`);
  the edge choice gates that idea, and whether NPM can load the plugin at all
  is part of this question rather than settled above it.
- Does the proxy host's nginx have Wasm support? Unverified; one recon command
  on the host would answer it.
- Multi-node wakeups: one Traefik with file-provider routes to tailnet
  addresses, or one Traefik per node with per-route `sablierUrl`? The remote
  backend address question is untested.
- Is the Dokploy Traefik on the VPS version 3.6 or newer? `traefik.docker.allownonrunning`
  needs it, and the running image tag has not been read.

## AI reviewer (`plans/ai-reviewer-prime-agent.md`)

- Trace viewer: Phoenix or Langfuse? Phoenix is one container (Elastic
  License 2.0); Langfuse is six (web, worker, ClickHouse, Redis, Postgres, S3
  storage; MIT outside its `ee/` folder) and has the stronger workflow for
  scoring runs. Both publish ARM64 images (`docker buildx imagetools inspect`,
  2026-11-02). Langfuse's size matters less if it runs only when needed behind
  Sablier (`ideas/on-demand-container-wakeups.md`), which depends on that
  idea's open reverse-proxy questions.
- Where do the reviewer's own instructions live? The plan proposes a private
  config repo (prompt, skills, tool manifest, `/refine` lessons) and keeps the
  shared rules public in `repo/review.md` and `AGENTS.md`. `AGENTS.md` says
  the setup lives in this repo so every harness gets it; is a private repo for
  one agent's setup within that rule?
