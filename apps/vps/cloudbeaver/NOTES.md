# CloudBeaver — notes

## Sources

What `README.md`'s stack was derived from.

| Source | Version read | What was taken |
|---|---|---|
| CloudBeaver source: `CBConstants.java`, `CBApplication.performAutoConfiguration` | `main`, 2026-11-09 (tags are named differently from the image) | `CB_SERVER_NAME`, `CB_ADMIN_NAME`, `CB_ADMIN_PASSWORD` skip the setup wizard on the first start |
| `dbeaver/cloudbeaver` on Docker Hub | `26.2.4`, 2026-11-09 | arm64 image, port 8978, `/opt/cloudbeaver/workspace` |
| CloudBeaver source: `io.cloudbeaver.service.security/plugin.xml`, `RPSessionHandler.java`, `RPAuthProvider.java`, `CBServerConfigurationController.java` | `main` and tag `26.2.5`, 2026-11-20 (no `26.2.4` tag) | the `reverseProxy` provider is in the Community edition (OIDC is not), takes the user from a header (default `X-User`), and is switched on in the runtime config (`enabledAuthProviders`, `authConfigurations`) |
| CloudBeaver source: `RPSessionHandler.java`, `RPConstants.java`, `RPAuthProvider.java`, `plugin.xml`; `service.admin.graphqls` | tag `26.2.5`, 2026-11-21 | the provider has no check on where a request came from; it reads the user header and the team header (both configurable), and `X-Role`, `X-Role-TE`, `X-First-name`, `X-Last-name`, `X-Full-name`; it signs in when a session opens; `authConfigurations` entries have `id`, `provider`, `displayName`, `disabled`, `parameters`; `addConnectionsAccess` grants a connection to a team |
| Dokploy source: `utils/docker/collision.ts`, `collision/root-network.ts`, `utils/builders/compose.ts`, `utils/docker/domain.ts` | tag `v0.31.2` (the running version), 2026-11-21 | isolated deployment adds a network named after the app to every service, keeps networks a service already lists, and runs `docker network connect <app> dokploy-traefik` after each deploy |
| Authentik's Traefik forward-auth set-up | from memory, not re-read; checked live on 2026-11-20 (`/outpost.goauthentik.io/ping` answered 204, a request without a session was sent to Authentik) | `/outpost.goauthentik.io/auth/traefik` |

## Sign-in

**Authentik** (API, as `akadmin`): a proxy provider `cloudbeaver` in forward-auth, single-application mode, with
external host `https://<CloudBeaver host>` and Langfuse's provider's flows; an application `cloudbeaver` with a policy
binding for `homelab-admins`; the provider added to the embedded outpost, which runs inside Authentik's server container.
**Traefik** (labels in `compose.yaml`): the `cloudbeaver-authentik` forward-auth middleware after the tailnet
allowlist, and a router that sends `/outpost.goauthentik.io/` on this hostname to Authentik. Without an Authentik
session, a request is sent to Authentik's sign-in and never reaches CloudBeaver, so it wakes nothing (`curl`).

**One sign-in, since 2026-11-21.** The Community edition has no OIDC; its `reverseProxy` provider takes the user from
a request header, and trusts whoever sends it. A first try on 2026-11-20 was switched off the same day, because any
container on `dokploy-network` could have sent the header. Now only Traefik can reach CloudBeaver:

- **Its own network.** Dokploy's isolated deployment is on for this service: Dokploy creates a network named after the
  app, puts every service on it, and connects Traefik after each deploy. `cloudbeaver` lists no network, so it is on
  that one only; the `traefik.docker.network` label names it. Checked after the deploy (`docker network inspect`): its
  members are Traefik, `cloudbeaver` and `pg-relay`; from a throwaway container on `dokploy-network`, CloudBeaver's
  name does not resolve and its address times out. If Dokploy recreates Traefik, the connection is gone until this
  service is deployed again, and CloudBeaver is unreachable — closed, not open.
- **`pg-relay`** (haproxy, the image `pg-proxy` pins) is on both networks and forwards TCP port 5436 to `pg-proxy`
  and nothing else, so it does not open a way to CloudBeaver's HTTP port. The saved connection's host was changed
  from `pg-proxy` to `pg-relay` in `data-sources.json` (backup `data-sources.json.bak-20261121` beside it).
- **The headers.** Traefik's `cloudbeaver-identity` middleware deletes every identity header CloudBeaver reads from
  the client's request and sets `X-Team: admin`; then forward-auth copies Authentik's `X-authentik-username` onto
  it. Only `homelab-admins` pass Authentik, so every user it lets through is a CloudBeaver admin.
- **CloudBeaver's runtime config** (`.data/.cloudbeaver.runtime.conf` in the volume, backup `.bak-20261121`):
  `enabledAuthProviders` `local` and `reverseProxy`, and one `authConfigurations` entry: id `authentik`, provider
  `reverseProxy`, `user-header` `X-authentik-username`, `team-header` `X-Team`, `logout-url` the outpost's
  `/outpost.goauthentik.io/sign_out` on this host. Set by hand with CloudBeaver stopped; it is not in `compose.yaml`
  because CloudBeaver writes this file itself.
- **Checked on 2026-11-21:** through Traefik without a session, with or without forged `X-authentik-username`,
  `X-User` and `X-Team`, the answer is a 302 to Authentik (`curl`). On the app's network, a session opened with
  `X-authentik-username` came back as that user, linked to `reverseProxy`, in the teams `admin` and `user`; without the
  header, anonymous. The `admin` team was granted the saved connection (`addConnectionsAccess`), which then connected
  through `pg-relay` (`initConnection`). A browser sign-in by the owner: UNTESTED.

## Dates

When the facts in `README.md` were true from, or were checked.

- Running since 2026-11-09. "Show all databases" was set in `data-sources.json` that day, and the auto-configuration was checked after the first start.
- Sign-in through Authentik set up on 2026-11-20 (`agents/journal/2026-11-20-db-ui-sign-in-authentik.md`); one sign-in, on its own network, on 2026-11-21 (`agents/journal/2026-11-21-cloudbeaver-one-sign-in.md`).
