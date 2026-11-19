# Sablier

Stops idle apps on the VPS and starts them again on the next request: Sablier,
reaching Docker only through a socket proxy, and Traefik's Sablier plugin in
front of each sleeping app (`agents/plans/sablier-wakeups.md`).

**Status:** see `agents/plans/sablier-wakeups.md`. Nothing in this stack is public, and it keeps no data.

- **Where:** remote VPS, deployed by Dokploy from `compose.yaml` here, on
  `dokploy-network`; no published port. The plugin block lives in Traefik's
  own config on the VPS (`NOTES.md`, "What lives outside this stack").
- **Backups:** none needed; it keeps no data.

## Making an app sleep

The idle time is per app. Use `apps/vps/blinko/compose.yaml` as the example:

1. In the app's `compose.yaml`, as a list of labels: `sablier.enable=true`, `sablier.group=<app>`,
   `traefik.docker.allownonrunning=true`, and the middleware `<app>-sablier` with `sessionDuration`.
   Every container of the stack needs `sablier.enable=true`, or the cleanup schedule removes it (`NOTES.md`).
2. Give the app a health check, and `restart: unless-stopped`; `always` brings it back when Docker restarts.
3. In its Dokploy domain, set the middleware to `<app>-sablier@docker`, then redeploy.

The app must have a trigger a person opens. Anything waiting on webhooks, or doing work with no HTTP traffic, should stay awake.

## Dokploy's Docker cleanup stays off

Dokploy's "Daily Docker Cleanup" (Settings → Server) removes every stopped container, and a sleeping app is a stopped container. Once
it is removed, Traefik has no route for it (404) and Sablier has nothing to start; only a redeploy brings it back. It has happened four times (`agents/journal/2026-11-13-cleanup-removed-sleeping-apps.md`).

Sources, upgrade checks, the replacement cleanup schedule and known failure modes: `NOTES.md`.
