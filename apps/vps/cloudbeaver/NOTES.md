# CloudBeaver — notes

## Sources

What `README.md`'s stack was derived from.

| Source | Version read | What was taken |
|---|---|---|
| CloudBeaver source: `CBConstants.java`, `CBApplication.performAutoConfiguration` | `main`, 2026-11-09 (tags are named differently from the image) | `CB_SERVER_NAME`, `CB_ADMIN_NAME`, `CB_ADMIN_PASSWORD` skip the setup wizard on the first start |
| `dbeaver/cloudbeaver` on Docker Hub | `26.2.4`, 2026-11-09 | arm64 image, port 8978, `/opt/cloudbeaver/workspace` |
| CloudBeaver source: `io.cloudbeaver.service.security/plugin.xml`, `RPSessionHandler.java`, `RPAuthProvider.java`, `CBServerConfigurationController.java` | `main` and tag `26.2.5`, 2026-11-20 (no `26.2.4` tag) | the `reverseProxy` provider is in the Community edition (OIDC is not), takes the user from a header (default `X-User`), and is switched on in the runtime config (`enabledAuthProviders`, `authConfigurations`) |
| Authentik's Traefik forward-auth set-up | from memory, not re-read; checked live on 2026-11-20 (`/outpost.goauthentik.io/ping` answered 204, a request without a session was sent to Authentik) | `/outpost.goauthentik.io/auth/traefik` |

## Sign-in

**Authentik** (API, as `akadmin`): a proxy provider `cloudbeaver` in forward-auth, single-application mode, with
external host `https://<CloudBeaver host>` and Langfuse's provider's flows; an application `cloudbeaver` with a policy
binding for `homelab-admins`; the provider added to the embedded outpost, which runs inside Authentik's server container.
**Traefik** (labels in `compose.yaml`): the `cloudbeaver-authentik` forward-auth middleware after the tailnet
allowlist, and a router that sends `/outpost.goauthentik.io/` on this hostname to Authentik. Without an Authentik
session, a request is sent to Authentik's sign-in and never reaches CloudBeaver, so it wakes nothing (`curl`).

**CloudBeaver's own login stays.** The Community edition has no OIDC. Its `reverseProxy` provider, which takes the user
from a request header, was switched on and tested on 2026-11-20, then switched off again the same day: CloudBeaver
cannot tell Traefik's requests from those of any other container on `dokploy-network`, so the header would be trusted
from all of them. The test left a user for the owner, with no provider, in CloudBeaver's database.

## Dates

When the facts in `README.md` were true from, or were checked.

- Running since 2026-11-09. "Show all databases" was set in `data-sources.json` that day, and the auto-configuration was checked after the first start.
- Sign-in through Authentik set up on 2026-11-20 (`agents/journal/2026-11-20-db-ui-sign-in-authentik.md`).
