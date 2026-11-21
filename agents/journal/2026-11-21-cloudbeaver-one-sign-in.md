# 2026-11-21 — CloudBeaver signs in once, through Authentik

**Who:** Claude Code (Opus 5.5)  **Scope:** `apps/vps/cloudbeaver/` on the VPS (Dokploy)  **Mode:** write
**Task:** owner, in session: drop CloudBeaver's second login, with a network only Traefik shares  **Skill:** none

## What changed

- Dokploy: isolated deployment on for the CloudBeaver service (API, `compose.update`); branch `cloudbeaver-header-sign-in`
  for the deploy. CloudBeaver now sits on the app's own network only; a new `pg-relay` service bridges Postgres.
- Traefik labels: `cloudbeaver-identity` (deletes client identity headers, sets `X-Team: admin`), forward-auth copies
  `X-authentik-username` (`apps/vps/cloudbeaver/NOTES.md`, "Sign-in").
- In the volume, with CloudBeaver stopped: the runtime config enables the `reverseProxy` provider (entry `authentik`);
  the saved connection's host `pg-proxy` → `pg-relay`. Through CloudBeaver's API: the `admin` team granted the saved
  connection. The owner's Authentik user now signs in as a CloudBeaver admin (the user left by the 2026-11-20 test).

## Snapshot / backup taken

CloudBeaver stopped, its workspace volume tarred to the owner's workstation
(`~/backups/cloudbeaver-pre-header-sign-in-2026-11-21/`): 22 entries, equal to the volume's. Both edited files also
have `.bak-20261121` copies beside them. Not restored.

## How it was verified

- Networks (`docker inspect`): `cloudbeaver` on the app's network only; that network holds Traefik, `cloudbeaver` and
  `pg-relay`. From a throwaway container on `dokploy-network`: CloudBeaver's name does not resolve, its address times out.
- Through Traefik, no session, with and without forged `X-authentik-username`, `X-User`, `X-Team`: 302 to Authentik.
- On the app's network: a session with `X-authentik-username` set to the owner's user is that user, teams `admin` and `user`; without
  the header, anonymous. The saved connection connected through `pg-relay`.

## Still open

- The owner's browser sign-in. UNTESTED until then.
- After the pull request merges: set the service's branch back to `main` (no redeploy needed).
- The saved connection reports saved credentials, while the README says not to save them
  (`agents/decisions/open-questions.md`).
