# 2026-11-18 — cache-1's web UI and Grafana sign in through Authentik

**Who:** Claude Code, at the owner's request  **Scope:** Authentik (two applications, one group), `cache-1`'s stack, OpenBao  **Mode:** write
**Task:** phase 2 of step B4a in `plans/home-overhaul.md`: native single sign-on where the app supports it  **Skill:** none

## What changed

- OpenBao: field `domain` added to `kv/general/authentik`; the owner replaced its expired `api` token. The four client
  values (`oidc_client_id`, `oidc_client_secret`, `grafana_oidc_client_id`, `grafana_oidc_client_secret`) added to
  `kv/homelab/artifact-keeper`.
- Authentik, through its API as `akadmin`: OAuth2/OpenID providers and applications `artifact-keeper` and
  `cache-grafana`, copying the `langfuse` provider's flows, scope mappings, signing key and subject mode, with grant
  types `authorization_code` and `refresh_token` and one strict callback each. Group `homelab-admins`, holding the owner's everyday account.
- `apps/homeserver/artifact-keeper/compose.yaml`: the backend's `AK_EXTERNAL_URL` and `OIDC_*` settings, and
  `cache.home.<zone>` added to `CORS_ORIGINS`; Grafana's root URL moved to `https://cache.home.<zone>/grafana/` and
  its generic OAuth settings added. Values not in the repo come from a `.env` that `ansible/cache.yml` now writes.
  `cache.yml` ran in check mode, then for real: the backend, web UI and Grafana were recreated (cache down for a few
  seconds).

## Snapshot / backup taken

None, as for the earlier cache-1 changes: the cache holds rebuildable state (`decisions/backup-tiers.md`), and
removing the `OIDC_*` variables and restarting disables the provider again.

## How it was verified

- Backend log: "Bootstrapped OIDC provider 'authentik' … from environment variables";
  `GET /api/v1/auth/sso/providers` through the proxy lists it.
- Both sign-in starts (`/api/v1/auth/sso/oidc/<id>/login` and `/grafana/login/generic_oauth`) redirect to
  Authentik's authorize endpoint with the `https://cache.home.<zone>` callback, scopes `openid profile email` and a
  PKCE challenge; Authentik answers the request with its login flow (302), not an error.
- Grafana's login page offered Authentik next to the local form; the owner then asked for password login to go:
  `GF_AUTH_DISABLE_LOGIN_FORM`, `GF_AUTH_BASIC_ENABLED: "false"` and OAuth auto-login, applied with `cache.yml`.
  After it, `/grafana/login` answers 307 to `/grafana/login/generic_oauth`, a password login to `/grafana/login` 400,
  and basic auth on `/grafana/api/org` 401.
- apt through the cache by IP: `Release` 200. The registry's token realm is now `https://cache.home.<zone>/v2/token`;
  a token from there, used on `http://10.22.33.137/v2/…/manifests/latest`, returned 200.

## Not verified

- A real sign-in by the owner into each app, and the admin role from `homelab-admins`.
