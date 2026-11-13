---
type: idea
status: "promoted to plans/sablier-wakeups.md"
verified: "no (upstream docs and source read 2026-11-01; nothing run on the lab)"
tags:
  - idea
  - docker
  - dokploy
  - resource-efficiency
---

# On-demand container wakeups (scale to zero)

**Status:** promoted to `plans/sablier-wakeups.md` (owner, 2026-11-07), on the VPS only. The research notes at the end
still apply to the home edge.
**In one line:** give every rarely-used stack a live URL that starts it on the
first request and stops it again after a quiet period, so dozens of niche
services can exist without any of them costing CPU or RAM while forgotten.
**Why try it:** `inventory/services.md` records Coder, jobops and Odyssues as not
running (whether that is deliberate is not recorded), and niche things get
dropped entirely because turning them back on is more effort than the thing was
worth. This turns "off" into a state the lab maintains, so
the constraint becomes how many stacks are awake at once instead of how many
are installed.
**Needs first:** a Traefik ≥3.6 that owns the route (Dokploy runs its own, but
`systems/vps.md` records that the version is not kept in this repo), a Sablier
container per Docker host, an HTTP ingress route per candidate, and a real
healthcheck per service. The home edge is Nginx Proxy Manager
(`inventory/services.md`, "in docs, not verified"), which has no Sablier
plugin — that node needs the dashboard-tile path or a proxy change.

## Design sketch

[Sablier](https://sablierapp.dev/) (AGPL-3.0, v1.19.1, ~3.1k GitHub stars on
2026-11-01; the upstream README says one developer maintains it) is the
only maintained scale-to-zero layer we found that plugs into an existing proxy. It sits
between the proxy and the workload: the proxy asks for a *group*, Sablier
starts every instance in it, waits for health, then lets traffic through.
A session is kept alive by traffic and expires after an idle period, at which
point the containers are stopped.

Four different "off" levels, only two of which are per-container:

| Level | Scope | Effect | Reclaims |
|---|---|---|---|
| Stop (`sablier.idle.replicas=0`, default) | per container | `docker stop` on session expiry | CPU + RAM fully; image and writable layer stay on disk |
| Pause (`--provider.docker.strategy=pause`) | global | `docker pause` (SIGSTOP) | CPU only, RAM retained, instant resume |
| Throttle (`idle.replicas>=1` + `idle.cpu`/`memory`/`blkio-*`) | per container | cgroup limits, process keeps running | partial; memory limits add pressure, not release |
| Remove | not Sablier | `compose down` / panel delete | disk too, and permanently unwakeable |

Compose awareness: Sablier reads `com.docker.compose.project`, `.service` and
`.depends_on`, and on a session start walks the dependency graph — dependencies
need no labels to be *started*, but only labelled containers are *stopped* with
the group. That gives three patterns: front-service-only (deps wake then stay
warm), whole-stack (label everything, usually wanted), and shared-db (one db in
several groups, sleeps only when all are idle). A start including dependencies
is capped at five minutes; one-shot migrations must never be labelled, because
a session is only ready when every member is.

Two label settings do the real work for bursty usage: `sessionDuration: 4h` means
the cold start is paid once per working burst and never again while clicking
around, and `sablier.running-hours` ("09:00-23:00", TZ=Asia/Kolkata) keeps
habitual services warm through the hours a human actually uses them.

Dokploy specifics (verified in its source, not yet on this host): its Traefik
runs the docker provider with `network: dokploy-network` and
`exposedByDefault: false`, and `traefik.yml` is only written when missing, so a
hand-added `experimental.plugins.sablier` block survives panel edits and
container recreates. Sleepable services need their own router labels plus
`traefik.docker.allownonrunning=true` (Traefik ≥3.6) — the panel's Domains UI
creates a router without the wake middleware, so one owner per host (corrected 2026-11-07: Dokploy v0.31.0's domains have a `middlewares` field,
`packages/server/src/utils/docker/domain.ts`, so the panel can keep the route). Panel
**Stop** is `docker compose stop` and stays wakeable; **Delete** is
`compose down` and is not.

## What stays expensive, and what does not fit

- While stopped: zero CPU/RAM, ports released. Disk is the real cost of
  sprawl (image + writable layer per stack).
- The trigger is an **HTTP request through the proxy**. Internal
  service-to-service calls, cron jobs that use container DNS, `psql`, SSH and
  raw TCP never wake anything; Traefik plugins are HTTP middlewares only.
- **Inbound-push services cannot sleep**: chat, webhooks, mail, anything that
  must answer an event nobody scheduled. A cold start makes the caller's
  request time out or arrive late, and Sablier queues nothing — it is a
  trigger, not a buffer. A chat server (Mattermost — run by the owner, not in
  `inventory/services.md`; from memory), a polled API (Hindsight, inside the
  `hermes` row) and the model router (9router, the `router9` row) all sit in
  this category: not one of them has a trigger a human opens.
- **Human-driven boards do fit.** Paperclip is sleepable while its agent
  heartbeats and schedules stay off (the owner's standing config: heartbeat
  interval OFF, wake-on-demand ON — from memory, not recorded in this repo),
  because its only traffic is the owner opening the board. Two caveats: turning on a CEO interval or any heartbeat makes it a
  scheduler that has to be awake at those ticks, and the idle timer measures
  *proxied HTTP traffic, not work* — a long agent run emits no requests, so a
  short session can expire and SIGTERM a run mid-flight. Size
  `sessionDuration` above the longest expected run.
- **Throttling is the wrong lever for chat.** Scale mode keeps the process
  and its heap resident, so it saves CPU/IO and returns no memory; for a
  RAM-bound service the only lever that returns memory is stopping it, and a
  schedule (`running-hours`) is the version of that which still answers during
  waking hours.
- The Compose-file API is wake-only: no start/stop-instance endpoint exists.
  "On" is a strategy call with a long `session_duration`; "off" is expiry or a
  manual `docker stop`. Do not enable `auto-stop-externally-started` if manual
  `docker start` is ever used.
- Coexistence with a Docker UI (Arcane): its auto-heal is safe (it filters
  `health=unhealthy` and skips stopped containers), but its updater recreates
  and therefore wakes sleeping stacks; its project **Down** removes containers.
  Opt sleeping stacks out with `com.getarcaneapp.arcane.updater=false`.

## Risks and costs

- Another component in front of public traffic, and a Yaegi plugin fetched from
  GitHub at proxy startup — pin its version and mount a plugin cache, or a
  GitHub outage becomes an ingress outage.
- Cold start is the app's own boot time; anything a human waits on
  synchronously is a bad candidate.
- The idle timer measures traffic, not work: batch jobs, agent runs and long
  uploads produce no proxied requests, so a session can expire under them.
- Status drift: sleeping apps read as stopped/crashed in Dokploy, Arcane,
  uptime checks and image updaters. Monitors must be excluded with
  `ignoreUserAgent`, and volume-backup jobs that stop → dump → start leave a
  sleeping container running until its next expiry.
- Copy-pasted label blocks collide on router/middleware names, and Traefik
  drops routers for divergent stopped containers sharing a name.
- Single-maintainer AGPL project (upstream README), frequent releases — pin versions.

## Promote when

Any of: the VPS runs out of RAM with several dormant stacks already installed;
the number of stacks recorded as not running passes roughly ten; or one disposable
stack gets a healthcheck and two weeks of real use without a failed wake.
opendota was named here as the natural pilot. It was deleted on 2026-11-13
(`journal/2026-11-13-remove-opendota.md`), so a pilot needs another stack.

## Sources

- `sablierapp.dev` docs: providers/docker, concepts (groups, strategies,
  how-it-works), features (scale-mode, stop-external-starts,
  warm-external-starts, running-hours), reference/labels, reference/api.
- Upstream source read 2026-11-01: `sablierapp/sablier` (`internal/api/*`,
  `docs/static/openapi.json`, provider docs), `sablierapp/sablier-traefik-plugin`
  README (label-based middleware needs Traefik ≥3.6, `traefik.docker.allownonrunning`).
- Dokploy source read 2026-11-01: `Dokploy/dokploy`
  `packages/server/src/setup/traefik-setup.ts`
  (docker provider, `network: dokploy-network`, traefik.yml written only when
  missing, LetsEncrypt edit round-trips the YAML) and
  `packages/server/src/services/compose.ts`
  (`stopCompose` = `compose stop`, `removeCompose` = `down`).
- Arcane docs and source read 2026-11-01: project controls, updater labels,
  `backend/pkg/scheduler/auto_heal_job.go` (unhealthy-only filter).
- Unverified here: the Traefik version actually running on the VPS, whether
  each candidate stack has a healthcheck, and whether its compose files use
  `restart: always` (which would resurrect sleeping containers on daemon
  restart). Vendor claims ~1.5–2 ms overhead per request; not measured here.

## Research notes — reverse proxies and multi-host (open, nothing tested)

Nothing in this section is decided, configured or run. It exists so the next
agent does not re-derive it, and it is the reason the status above is *needs
more research* rather than *researched*.

The edge-proxy choice itself, with the WAF, ban-tool and sign-in layers that
come with it, is researched in `ideas/edge-and-security-layers.md` and on hold
until the Pangolin decision (owner, 2026-11-01). Wakeups on the VPS do not
wait for it: Dokploy's Traefik stays either way.

### Can it work with Nginx Proxy Manager, the home edge?

Probably not through NPM itself. NPM is nginx behind a UI: its per-host
*Advanced* tab accepts raw nginx directives but cannot load new nginx modules,
and Sablier's nginx integration is a **Proxy-Wasm** plugin that needs an
nginx built with Wasm support (`sablierapp.dev`, reverse-proxies/nginx_proxywasm;
the same plugin serves Nginx, Envoy, Istio and Apache APISIX). The stock NPM
image is not documented to ship a Wasm-capable nginx. Whether a recent
release does, and what the proxy host's build actually contains, is unverified —
`inventory/services.md` lists NPM as "in docs, not verified".

Four paths, cheapest first:

1. **Wake tile, no plugin.** A dashboard tile or bookmarklet that calls the
   wake API, waits, then redirects. Works with NPM unchanged, but the wait is
   a blank page instead of Sablier's themed waiting page, and there is no
   automatic renewal while the tab sits idle. This is the only path that adds
   no component.
2. **A small Caddy behind NPM for sleepable hosts only.** NPM routes
   `app.example.com` to a Caddy container that holds the Sablier handler and
   proxies to the app. Two proxies in the path, but the edge stays NPM and the
   blast radius is one container. Caddy needs a custom build with the module
   compiled in (see below), so it is an image to maintain.
3. **Replace the edge with Caddy or Traefik.** That is the "which proxy owns
   the home edge" item in `decisions/open-questions.md`; not a decision this
   idea should force.
4. **Hand-written njs/nginx logic calling the wake API.** There is no
   maintained module; this is our own code at the edge. Not recommended.

### How Traefik would work across hosts

Facts that decide the shape (Traefik docs, and
`Dokploy/dokploy` `packages/server/src/setup/traefik-setup.ts` read 2026-11-01):

- A Traefik **docker provider watches exactly one Docker daemon**. There is no
  multi-daemon docker provider; one Traefik seeing several nodes means
  file-provider routes with fixed addresses, or one Traefik per node.
- The wake middleware is configured **per route** and names a `sablierUrl`, so
  one Traefik can talk to several Sabliers — one per node, each reachable over
  the tailnet. This is the only design where a single entry point wakes
  workloads on more than one host.
- On the node whose daemon Traefik watches, `traefik.docker.allownonrunning=true`
  keeps the router while the container is stopped. On a remote node the route
  is static (file provider) and survives anyway, but the backend address has to
  resolve once the container wakes — a stopped container has no network
  endpoint. Pointing such a route at a container name on a shared network, or a
  tailnet address, is **UNTESTED** here.
- The VPS is the easy node as far as Dokploy's *source* shows:
  `packages/server/src/setup/traefik-setup.ts` configures the docker provider against its own
  daemon with `network: dokploy-network` and `exposedByDefault: false`, and
  writes the static config only when missing. Not confirmed on the running
  host.
- The home side is the open part: NPM is the public entry
  (Cloudflare → NPM → container, `inventory/network.md`), so a central Traefik
  means replacing or fronting NPM — the same choice as above, one layer up.
- Two open sub-questions: one Traefik with per-route `sablierUrl` for the VPS
  versus one Traefik per node; and whether a wildcard certificate is needed for
  many sleeping apps — Dokploy's resolver is HTTP-01, and a wildcard needs a
  DNS-01 resolver with provider credentials in `traefik.yml` (source: Dokploy
  `getDefaultTraefikConfig()`).

### Other reverse proxies

| Proxy | Sablier integration | What it costs here | Fit |
|---|---|---|---|
| Traefik | Runtime plugin loaded through Yaegi, configured by labels or file; needs ≥3.6 for `traefik.docker.allownonrunning` | Nothing new on the VPS — Dokploy already runs it; one static-config block | Best fit for the VPS |
| Caddy | Native handler module, **compiled into** Caddy with xcaddy | A custom image that replaces or sits behind NPM | Cleanest config of the set; pays off only if the edge changes anyway |
| Nginx / NPM | Proxy-Wasm plugin in a Wasm-enabled nginx build | NPM cannot load it; a custom nginx means replacing NPM's reason to exist | Poor |
| Envoy | Same Proxy-Wasm plugin | Full xDS configuration for a two-host lab | Poor — huge config surface for the benefit |
| Apache APISIX | Same Proxy-Wasm plugin | A new control plane (etcd plus dashboard) | Poor |
| Istio | Same plugin via EnvoyFilter | Kubernetes-only; no cluster in this lab | Not applicable |

The Proxy-Wasm plugin is one artifact shared by Nginx, Envoy, Istio and APISIX;
Traefik and Caddy each have their own. So the real choice is **Traefik where it
already runs**, **Caddy if the edge is being replaced anyway**, or **NPM plus a
wake tile** if nothing else changes.

### Open questions

All four that block this — the edge proxy, NPM's Wasm support, one Traefik
versus one per node, and whether the VPS Traefik is new enough — are appended to
`decisions/open-questions.md` under "Reverse proxy (home edge and VPS)", so
they live in one list and are not restated here.
