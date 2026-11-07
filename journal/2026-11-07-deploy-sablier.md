# 2026-11-07 — deployed Sablier, with Blinko sleeping when idle

**Who:** the owner, with Claude Code  **Scope:** remote VPS: Traefik's static config, new Dokploy project `sablier`, Blinko's domain and labels  **Mode:** write
**Task:** steps 1 to 5 of `plans/sablier-wakeups.md`  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- `/etc/dokploy/traefik/traefik.yml` loads the Sablier plugin v1.4.0 (block in `apps/vps/sablier/README.md`). Backup beside it:
  `traefik.yml.bak-20261107`.
- New Dokploy project `sablier`, a Compose service from `apps/vps/sablier/` on `main`, with `autoDeploy` off. Created and deployed
  through the Dokploy MCP (`agents/mcp/dokploy`), driven over stdio from a script, as it was not loaded in the session.
- Blinko's Dokploy domain names the middleware `blinko-sablier@docker`, and its labels set a 20-minute idle time (10 for the first tests).
- The socket proxy was replaced by one that allows only the calls Sablier makes (PR 48): the first one let a request to create a container reach Docker.

## Snapshot / backup taken

`traefik.yml.bak-20261107`, and nothing else: no data changed. Blinko's notes are in the shared cluster's backups.

## What went wrong

- **The first Traefik change was rolled back by my own check.** It waited for "Plugins loaded", which Traefik logs only at INFO level,
  and Dokploy's Traefik logs errors only. The second try checked for the plugin's files and for "Plugins are disabled". Traefik restarted
  three times, about 13 s each, during which no site answered.
- **A recreated container breaks its route for a few seconds.** Compose creates the replacement under a temporary name and renames it;
  Sablier 1.19.1 takes the temporary name and does not follow the rename, so requests get 500. Its 30-second reconciliation corrects
  it: 10 s of 500s on Blinko's redeploy, and under 30 s in a throwaway stack. Upstream issue #1136, fixed in Sablier's code on 2026-10-28,
  not in a release yet. The first time, Sablier was restarted by hand before that could happen, so it looked permanent.
- **The new socket proxy was unhealthy at first:** its health check needs `-allowhealthcheck` (PR 49). Dokploy's deploy stopped before
  recreating Sablier, which waits for the proxy; the proxy served the running Sablier meanwhile.
- **The VPS was unreachable over the tailnet for about 4 minutes around 08:19 UTC,** while its public sites answered. No reboot, and no
  firewall or Docker error in the logs. The cause is not known. Afterwards the path went through Tailscale's relay instead of direct.

## How it was verified

| Check | Result |
|---|---|
| Traefik after the plugin | all 11 routes gave the same status code as before |
| Plugin server unreachable (throwaway Traefik v3.6.7 on the workstation) | Traefik answered after 12 s instead of 4 s; other routes worked; plugin routes gave 404 |
| Cold wake through the public domain | 6.4 to 6.5 s; the first answer is a 302, as when Blinko is awake |
| Idle stop, 10 minutes | stopped 10 minutes after the last request |
| Idle stop, 20 minutes | stopped at 09:53 UTC, 20 minutes after the last request; the proxy refused nothing. Sablier also logged an expiry for the temporary name, which no longer existed |
| Sablier stopped, Blinko running | Blinko kept answering (200) |
| Sablier stopped, Blinko asleep | 500 until Sablier was back; then a normal wake |
| Sablier restarted | it stopped Blinko, by design; the next request woke it |
| Socket proxy rules (throwaway proxy on the VPS) | allowed calls worked on a real container; creating containers, exec, kill, update, delete, images, info, logs, file copies, a `../` path and a client with another name were refused |
| Behind the new proxy | wakes and stops worked, and the proxy refused nothing (its log) |

The socket proxy closes Sablier's event stream now and then, and Sablier logs `unexpected EOF` and reconnects.

## Still open

- Blinko's `autoDeploy` reads `true` in Dokploy, while `journal/2026-11-07-deploy-blinko.md` says it was created with it off. The merges
  did not deploy it. Left as it is (owner, 2026-11-07).
- A Docker restart while Blinko sleeps was not tried; it would drop every app on the VPS. `unless-stopped` should keep it stopped.
- Browser and app clients were not tried; only `curl`.
