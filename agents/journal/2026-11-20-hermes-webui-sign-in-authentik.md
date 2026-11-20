# 2026-11-20 — Hermes WebUI signs in through Authentik

**Who:** Claude Code (Opus 5.5)  **Scope:** `apps/vps/hermes-webui/` on the VPS, Authentik, OpenBao  **Mode:** write
**Task:** owner, in session: sign-in for the second Hermes WebUI, password kept  **Skill:** none

## What changed

- Authentik (API, as `akadmin`): group `hermes-webui-1` with the owner's user; OAuth2 provider and application
  `hermes-webui-1`; policy bindings for `hermes-webui-1` and `homelab-admins` (`apps/vps/hermes-webui/NOTES.md`, "Sign-in").
- OpenBao `kv/dokploy/hermes-webui`: fields `oidc_client_id`, `oidc_client_secret`, `authentik_domain`, `domain` (`bao kv patch`).
- Dokploy: four environment lines referencing those fields; the service's branch set to `hermes-webui-oidc` for one
  test deploy, then back to `main` after the merge.
- Compose: the `HERMES_WEBUI_OIDC_*` settings; the password is unchanged.

## Snapshot / backup taken

Tar copies of both volumes (`hermes-webui-home`, `hermes-webui-workspace`) streamed to the owner's workstation
before the deploy. Their entry counts equal the file counts in the volumes (`find | wc -l` on the VPS), and `tar -t` read
each archive to the end. Not restored; not the stack's real backup, which is still to do.

## How it was verified

- Pinned image `0.52.561` has native OIDC (`auth_oidc.py`, and `login.js` with the #7056 change), read inside the image.
- After the deploy: the container healthy; `GET /api/auth/status` says `oidc_enabled: true`, `password_auth_enabled: true`.
- `GET /api/auth/oidc/start` answers 302 to Authentik's authorize endpoint with `response_type=code`, PKCE S256, a state
  and the https callback; Authentik answers that with its login flow, not a redirect-URI error (`curl`).
- The login page still shows the password field (`curl`).

## Still open

- A full sign-in in a browser, by the owner (needs the second factor). UNTESTED until then.
- The person using this instance has no Authentik account yet; the owner makes one in `hermes-webui-1`.
- Dropping the password, once sign-in is used (`NOTES.md`, "Sign-in").
- Auto-deploy setting disagrees with `NOTES.md` (`agents/decisions/open-questions.md`, "Docs that disagree").
