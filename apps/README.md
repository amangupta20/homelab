# Apps — Compose stacks as code

Every container stack the lab runs, one folder each, grouped by the host whose
container manager deploys it:

```
apps/homeserver/<app>/   deployed on the homeserver (Portainer today)
apps/vps/<app>/          deployed on the remote VPS by Dokploy
```

Each app folder holds:

- `compose.yaml` — the stack. Every value that is secret or machine-specific is
  a reference (`${VAR}`, or a `secrets:` file), never the value.
- `.env.example` — every variable the stack reads, with placeholders
  (`__PASTE_ONCE__`) and a comment saying where the real value lives in OpenBao.
- `README.md` — only if the app needs more than the inventory row says: data
  location, ports, quirks.

## Rules

- No real `.env` files; `.env` is git-ignored and the scan blocks secrets.
- CI runs `docker compose config` on every compose file here
  (`decisions/pull-request-gate.md`).
- Moving a stack in is a plan, not a drive-by: old copy keeps running until
  the new one is healthy (`plans/migration.md`).

## Apps

- `vps/openbao/` — the secret store; defined, not deployed.
