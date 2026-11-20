# 2026-11-20 — pgAdmin and CloudBeaver sign in through Authentik

**Who:** Claude Code (Opus 5.5)  **Scope:** `apps/vps/pgadmin/`, `apps/vps/cloudbeaver/`, Authentik, OpenBao  **Mode:** write
**Task:** owner, in session: sign-in for the VPS apps, after Hermes WebUI  **Skill:** none

## What changed

- pgAdmin: Authentik OAuth2 provider and application `pgadmin`, bound to `homelab-admins`; client ID and secret in
  OpenBao `kv/dokploy/pgadmin`; three Dokploy environment references; OIDC in `compose.yaml` next to its own login.
- CloudBeaver: Authentik proxy provider and application `cloudbeaver` (forward-auth, single application), bound to
  `homelab-admins`, on the embedded outpost; forward-auth labels in `compose.yaml`, in front of CloudBeaver's own login.
  Its `reverseProxy` header login was switched on in `.data/.cloudbeaver.runtime.conf`, tested, and switched off again
  by restoring the file (`apps/vps/cloudbeaver/NOTES.md`, "Sign-in", says why).
- Both services deployed once from branch `vps-db-ui-sign-in`, then set back to `main` after the merge.

## Snapshot / backup taken

Tar copies of `pgadmin-data` (7 files) and `cloudbeaver-workspace` (21 files) on the owner's workstation before the
deploys; entry counts equal the volumes' file counts. The runtime config before the edit: `.cloudbeaver.runtime.conf.bak-20261120`.

## How it was verified

- pgAdmin `9.19.0`, locally with placeholders: the config parses, the login page shows the Authentik button. On the VPS:
  the Authentik button answers 302 to Authentik's authorize endpoint with the https `/oauth2/authorize` callback, and
  Authentik shows its login flow (`curl`).
- CloudBeaver, through Traefik: no session, or a made-up `X-authentik-username` with no session, both get 302 to
  Authentik; the outpost's `ping` answers 204 (`curl`). Inside `dokploy-network`, with `reverseProxy` on, a session
  opened with `X-authentik-username` set to the owner's user came back as that user; after the restore, anonymous.
- Authentik's `check_access`: the owner's user passes both applications, `akadmin` does not.

## Still open

- A full browser sign-in to each, by the owner. UNTESTED until then.
- pgAdmin's Authentik account has no server yet (`apps/vps/pgadmin/NOTES.md`, "Sign-in").
- CloudBeaver signs in twice (Authentik, then its own login); one sign-in would need a way to trust only Traefik.
