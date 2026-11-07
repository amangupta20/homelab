---
type: plan
status: "in progress (step 2)"
verified: "partially (Traefik's plugin loaded on the VPS 2026-11-07; the rest is not deployed yet)"
hosts:
  - Remote VPS
tags:
  - plan
  - docker
  - dokploy
---

# Sablier wakeups

**Status:** in progress (step 2). Promoted from `ideas/on-demand-container-wakeups.md`, which holds the research (owner, 2026-11-07).

**Goal:** a rarely used app on the VPS stops when idle and starts again on its next request, with Blinko as the test.
**Done when:** Blinko stops after its idle time, a request through its domain starts it and gets a normal answer, and stopping Sablier does not
take a running Blinko offline. The results are in `journal/`.

Blinko uses about 172 MB (`docker stats`, 2026-11-07), with 17 GB available on the VPS, so this proves the pattern rather than saving memory. Home apps are out of scope.

## Decisions (owner, 2026-11-07)

- Blinko first. Its scheduled jobs not running while it sleeps is acceptable.
- Start with a 10-minute idle time, because it is easy to test, then choose the real one. It is set per app.
- Plugin downloads on each Traefik start are acceptable once tested ("If the plugin server is down" in `apps/vps/sablier/README.md`).

Agent's choices:

- The `blocking` strategy rather than a waiting page, so that API clients get data instead of HTML.
- `failOpen`, so Sablier being down does not block an app that is running.
- A socket proxy, as in upstream's example. `POST=1` leaves it able to act on containers, so it limits rather than removes what Sablier could do.

## Steps

1. **Load the plugin in Traefik.** (Done 2026-11-07.) — gate: every route answers as it did before.
2. **Merge this, and deploy `apps/vps/sablier/` in Dokploy,** with `autoDeploy` off. — gate: Sablier connects to Docker and has no published port.
3. **Redeploy Blinko with its labels, then set its domain's middleware to `blinko-sablier@docker`.** — gate: Blinko answers through its domain.
4. **Test:** the idle stop, a wake from a browser and from an API client, how long a wake takes, Sablier stopped while Blinko runs and while it sleeps,
   and a Docker restart while it sleeps. — gate: a journal entry with the results.
5. **Choose the real idle time** (owner).

To undo it: clear the domain's middleware and redeploy Blinko. To remove the plugin, restore `/etc/dokploy/traefik/traefik.yml.bak-20261107` and restart Traefik.

## Links

`ideas/on-demand-container-wakeups.md`, `apps/vps/sablier/README.md`, `apps/vps/blinko/`.
