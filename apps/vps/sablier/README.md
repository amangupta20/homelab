# Sablier

**Status:** see `plans/sablier-wakeups.md`. Nothing in this stack is public, and it keeps no data.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| `sablierapp/sablier`: `examples/docker/socket-proxy.yml`, `docs/content/providers/docker.md` | `v1.19.1`, 2026-11-07 | both services, the proxy's flags, the internal network |
| `sablierapp/sablier-traefik-plugin`: `README.md` | `v1.4.0`, 2026-11-07 | the plugin block and the labels an app needs |

Dokploy's template was not read. Choices that differ from the sources:

- No published port.
- `dokploy-network` instead of the Compose default network, because Traefik is on it.
- `--provider.reject-unlabeled-requests` and `--provider.verify-enabled-on-expiration`, so it only acts on labelled containers.

## What lives outside this stack

The plugin block is in `/etc/dokploy/traefik/traefik.yml` on the VPS, where Dokploy only writes the file if it is missing:

```yaml
experimental:
  plugins:
    sablier:
      moduleName: "github.com/sablierapp/sablier-traefik-plugin"
      version: "v1.4.0"
```

Traefik needs a restart to read it (about 13 s, 2026-11-07).

## Making an app sleep

The idle time is per app. Use `apps/vps/blinko/compose.yaml` as the example:

1. In the app's `compose.yaml`, as a list of labels: `sablier.enable=true`, `sablier.group=<app>`,
   `traefik.docker.allownonrunning=true`, and the middleware `<app>-sablier` with `sessionDuration`.
2. Give the app a health check, and `restart: unless-stopped`; `always` brings it back when Docker restarts.
3. In its Dokploy domain, set the middleware to `<app>-sablier@docker`, then redeploy.

The app must have a trigger a person opens. Anything waiting on webhooks, or doing work with no HTTP traffic, should stay awake.

## If the plugin server is down

Traefik downloads the plugin from `plugins.traefik.io` on every start, even with a copy in the container. Tried on the workstation with
Traefik v3.6.7, 2026-11-07, with that host and then DNS made unreachable: Traefik answered after 12 s instead of 4 s, other routes worked,
and routes using the plugin returned 404. They stay that way until Traefik restarts with the server reachable.
