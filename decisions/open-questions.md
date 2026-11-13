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
- Answered by the owner, 2026-11-05, for the item above: yes, it is the plan;
  `ansible/` started 2026-11-06. The item stays for the owner to close.
- cloud-init: one committed template per VM, or generated?
- `iac/oci/run.sh` reads `kv/general/`, where the owner keeps OpenTofu's secrets
  because they are not specific to one host (2026-11-05). `systems/openbao.md` says
  checkouts read `kv/homelab/*` only. It works today with an admin token; a
  narrower checkout policy would need those paths added. Who updates which?
- Is the live VPS outside the `homelab-iac` compartment? `iac/oci/README.md`
  relies on it, and the VPS's compartment has not been checked.
- Answered by the owner, 2026-11-05, for the item above: `iac/oci/` uses a separate,
  new Oracle account, so the VPS is not in it at all. The item stays for the owner
  to close.

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
- Answered by the owner, 2026-11-10, for the item above: Authentik, without
  comparing the lighter candidates (`decisions/sso-authentik.md`,
  `apps/vps/authentik/`).

## Not planned yet

- Observability: wanted, not deployed. Prometheus/Grafana is an assumption,
  not a choice. Whether Uptime Kuma runs at all is unknown
  (`inventory/services.md`).
  Owner, 2026-11-14: when this is planned, include the Home router. The
  package `prometheus-node-exporter-lua` is in its feed and not installed
  (`apk search`, 2026-11-14).

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
  Agent's note, 2026-11-07, for the owner to close: it runs `traefik:v3.6.7` (`docker ps`).

## AI reviewer (`plans/ai-reviewer-prime-agent.md`)

- Trace viewer: Phoenix or Langfuse? Phoenix is one container (Elastic
  License 2.0); Langfuse is six (web, worker, ClickHouse, Redis, Postgres, S3
  storage; MIT outside its `ee/` folder) and has the stronger workflow for
  scoring runs. Both publish ARM64 images (`docker buildx imagetools inspect`,
  2026-11-02). Langfuse's size matters less if it runs only when needed behind
  Sablier (`ideas/on-demand-container-wakeups.md`), which depends on that
  idea's open reverse-proxy questions.
  - 2026-11-10: the owner chose Langfuse in a working session, over Phoenix
    and Opik, to deploy next after Authentik and to learn evaluation on
    (`plans/ai-reviewer-prime-agent.md`, step 6).
- Where do the reviewer's own instructions live? The plan proposes a private
  config repo (prompt, skills, tool manifest, `/refine` lessons) and keeps the
  shared rules public in `repo/review.md` and `AGENTS.md`. `AGENTS.md` says
  the setup lives in this repo so every harness gets it; is a private repo for
  one agent's setup within that rule?

## Prime reviewer B2 runtime storage (2026-11-03)

- The owner requested moving reviewer sessions and traces to a dedicated
  private B2 bucket, keeping prompts and lessons in Git. The existing
  `kv/dokploy/b2` entry contains only `applicationKey` (field names checked
  with `bao kv get -format=json`, 2026-11-03); dedicated reviewer access is
  still needed. Its endpoint, bucket, region and scoped key will live in
  OpenBao at `kv/general/prime-reviewer-b2`, with a copy of the required
  runtime fields in the caller repository's Actions secrets. No credentials
  belong in this repository. Activation and migration restore testing remain
  pending that access and the caller workflow merge.

- Follow-up, 2026-11-03: the owner supplied the runtime fields; HTTPS endpoint
  normalization supplied the missing region. A copy at the agreed OpenBao
  path and five Actions secrets are configured. Read-only B2 authorization
  verified the key is restricted to the reviewer bucket, whose ACL is private.
  Two sessions and two traces were uploaded and restored with matching file
  contents. The remaining rollout step is the caller merge and final refresh
  after its last legacy review; the owner may close this item after cutover.

- Follow-up, 2026-11-03: cutover happened. PR 30 merged after the final
  refresh, and PR 31 was the first B2 run
  (`journal/2026-11-03-prime-reviewer-b2-migration.md`). Left for the owner
  to close.

## Edge and security layers (on hold until the Pangolin decision)

Research: `ideas/edge-and-security-layers.md`. Owner, 2026-11-01: the whole
group waits on the first item.

- Pangolin or not: no inbound ports at home through a tunnel to an edge VPS,
  or keep the static IP and inbound forwards? If yes, on which VPS (an
  E2.1.Micro or the A1), and Option A (the edge Traefik with CrowdSec AppSec
  only) or Option B (plus BunkerWeb at home)?
- The two-NPM split (public and private by listener), approved 2026-10-27, is
  back to research (owner, 2026-11-01). The home edge candidates are
  BunkerWeb, NPMplus, Caddy, Traefik or Pangolin's Traefik; the WAF engine
  follows from it.
- Origin protection for whichever edge is chosen: Cloudflare-only source
  ranges, Authenticated Origin Pulls, or no inbound ports.
- CrowdSec: where its local API lives (VPS or home), and which bouncers run
  where.
- Forward-auth for apps with no sign-in of their own: Badger (Pangolin),
  Authelia, or a helper such as oauth2-proxy. The SSO provider choice itself
  is not blocked by this.
- Whether the internal proxy sits behind Tailscale, and whether AdGuard
  becomes the tailnet's DNS.
- Virtual router VM on XCP-ng: owner leaning towards it, deferred.

## Shared Postgres (Pigsty) topology

Chosen by the owner on 2026-11-01 (`plans/shared-postgres.md`, "Topology");
these parts are open:

- Where the primary normally lives once both nodes exist: home or the second
  VPS.
- How the etcd tiebreaker runs on the Dokploy host: Pigsty-managed on the
  host, or a container under Dokploy outside Pigsty.
- Phase 1 etcd: one member or three from the start (two members is weaker
  than one — agent's note; the owner's answer is recorded below).
- Pigsty on arm64 / Ubuntu 24.04: unverified.
- Where Pigsty's manager runs before there is a home VM.
- Home-to-VPS round trip: below 50 ms per the owner, not measured; measure
  jitter with `mtr` over hours before etcd spans sites (**UNTESTED**).
- The second VPS: not bought yet ("soon", owner, 2026-11-01).
- For the item above: it exists as `pigsty-1` since 2026-11-06, in a separate Oracle
  account from the Remote VPS and the same region as far as recalled. The item stays
  for the owner to close.
- Answered by the owner, 2026-11-01, for the "Phase 1 etcd" item above: one
  member on the second VPS in phase 1; the tiebreaker on the Dokploy host is
  added when the home node starts. The item stays for the owner to close.
- The second VPS and the Remote VPS on one provider would hold two of three
  etcd members: an Oracle region or account problem stops the database even
  with home healthy. Separate account or region, or accept?
- Tailscale key expiry on the database and etcd nodes: turn it off or tag
  them, so a node does not drop out of the cluster when its key expires.
- For the item above: `pigsty-1` is tagged since 2026-11-06, so its key does not expire
  (`tailscale status --json`). The home node will need the same. The item stays for the
  owner to close.
- For "Pigsty on arm64 / Ubuntu 24.04": Pigsty v4.5.0's docs list it as supported
  (`pigsty.io/docs/ref/linux`, read 2026-11-06), and it has run on `pigsty-1` since then
  (`journal/2026-11-06-install-pigsty.md`). The item stays for the owner to close.
- For "Where Pigsty's manager runs": on `pigsty-1` in phase 1 (agent's recommendation,
  2026-11-06, after the owner chose one node only). The item stays for the owner to close.
- Pigsty's pgBackRest setup makes the one selected repository `repo1`, while
  `skills/back-up-a-service/` says `repo1` Garage, `repo2` B2; the owner wants B2
  first (`plans/shared-postgres.md`, "Backups"). Which numbering wins, and how a
  second repository gets added, is untested.
- `decisions/backup-tiers.md` keeps "3 daily, 1 weekly, 1 monthly" on B2, which
  pgBackRest cannot express; the owner chose one full backup for now
  (`plans/shared-postgres.md`, "Backups"). Which wording should the decision keep?
- For later, not now (agent's notes, owner has not decided): `pg_vault_tde` encrypts table values
  with keys from OpenBao, and OpenBao's Postgres secrets engine can issue short-lived logins per app.
  Neither is set up. Pigsty's page lists the extension's limits (`pigsty.io/ext/e/pg_vault_tde`).
- Nothing alerts when a scheduled pgBackRest backup stops running; the rule added on 2026-11-06 covers
  only WAL archiving. What should watch backup age?
  Agent's note, 2026-11-07, for the owner to close: `vmalert` now watches it, with the rules in
  `ansible/pigsty/patch-node.sh` (`journal/2026-11-07-backup-age-alerts.md`). They run on `pigsty-1`, so they
  say nothing if that node is down.
- `archive_timeout`: `plans/shared-postgres.md` says 60 s; the live cluster has 300 s, from Pigsty's `oltp`
  template (`pg_settings`, 2026-11-07). A quiet database can lose up to 5 minutes rather than 1. Which is wanted?
  Agent's note, 2026-11-09, for the owner to close: the owner chose 300 s as the default (600 also acceptable),
  lowered only when an app's usage needs it; `plans/shared-postgres.md` now says so, with the caveat that the
  setting covers the whole server.
- The `hermes` Dokploy project (agent, WebUI, Hindsight) and its updater schedule are not in this repo;
  `inventory/services.md` only lists the project. The updater follows `:latest` and, on every new agent
  image, re-seeds the volume that loses the Hindsight plugin's client
  (`journal/2026-11-08-hermes-hindsight-plugin-import.md`). Bring the stack in, pin its images, or keep it
  outside? Agent's note, 2026-11-08.

## Home router (OpenWrt)

Page: `systems/router.md`. Agent's notes, 2026-11-13, for the owner to close.

- IPv6 for LAN devices: the ISP router gives the Home router an address but
  delegates no prefix (`ifstatus wan6`, 2026-11-13), so devices behind it are
  IPv4-only. Relay mode on the Home router, bridge mode on the ISP router, or
  stay IPv4-only on the LAN?
  Agent's note, 2026-11-14, for the owner to close: relay mode is on and a
  laptop gets IPv6 through it (`systems/router.md`). It has run for minutes,
  not days.
- IPv6 on the ISP line was measured dead on 2026-11-12 (address and default
  route present, 100% loss to two public hosts, from the router and a laptop;
  flashing session notes) and working on 2026-11-13 (`ping -6`, 0% loss). The
  cause of the earlier failure is unknown. While it was dead the router's
  package manager stalled for about an hour on a dual-stack download host; if
  it stalls again, check IPv6 first.
- Double NAT: the Home router sits behind the ISP router. Bridge mode on the
  ISP router, or keep it routing? The earlier research is in
  `ideas/edge-and-security-layers.md`, "Physical router".
- Firmware source: the router runs a community build that is one community
  release behind (flashing session notes, 2026-11-12), and official support is
  two open pull requests. Stay on community builds, or move to an official
  image once one exists? Either move drops the added packages, and a failed
  upgrade needs the serial console.
  Agent's note, 2026-11-14, for the owner to close: upgraded to the current
  community release, v1.0.1, at the owner's request. The question of moving
  to an official image stays.
- The serial-console recovery and both manual backups are untested. Is a
  recovery drill wanted before the router carries the lab?
- Nothing backs up the router's config on a schedule, and
  `systems/backups.md` has no row for it. Should it get one
  (`skills/back-up-a-service/`)?
- Tailscale is installed on the router but not logged in. Should the router
  become the subnet router for the home subnet, and which machine advertises
  that subnet today? The laptop lost its route to the router once in the
  flashing session because it accepted a subnet route for the same range from
  the tailnet.
  Agent's note, 2026-11-14, for the owner to close: the router is signed in
  and advertises the home subnet (`systems/router.md`). The route is not
  approved yet, an older approval for the same range may still exist on
  another machine, and a laptop that accepts routes will send home-subnet
  traffic through the tailnet even when it is at home.
- `inventory/network.md` lists `.254` and `.160` from the docs. Both answer on
  the router's LAN (`ip neigh`, 2026-11-13), but which machines they are was
  not checked.
- The hourly channel-scan script from the flashing session is still on the
  router with its cron line commented out. Delete it, or keep it for manual
  runs?
- GitHub release downloads are slow on this line and have no IPv6 address to
  fall back on (`systems/router.md`, "Why IPv6 matters"). Send only those
  hosts through a tunnel to the VPS (policy routing on the router), or live
  with it?
  Agent's note, 2026-11-14, for the owner to close: set up as a tailnet
  route advertised by the VPS (`systems/router.md`, "Detour for GitHub
  downloads"), waiting for approval and untested. Every tailnet device that
  accepts routes will use it too.
- The router's package database names a Wi-Fi daemon that is not the one on
  disk (`systems/router.md`, Rules). Leave it until the next firmware image,
  or take another short Wi-Fi outage to put the database right?
  Agent's note, 2026-11-14, for the owner to close: the firmware upgrade
  replaced the database, and the full daemon is now installed properly.
- `usteer` now moves devices between the two radios. It was installed while
  Wi-Fi at the edge of range was still being tested, and nothing here shows
  whether it helps or causes disconnects. Keep it, tune it, or remove it?
