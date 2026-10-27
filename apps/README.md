# Apps — Compose stacks as code

Every container stack the lab runs, one folder each, grouped by the host whose
container manager deploys it:

```
apps/homeserver/<app>/   deployed on the homeserver (Portainer today)
apps/vps/<app>/          deployed on the remote VPS by Dokploy
```

Each app folder holds:

- `compose.yaml` — the stack. Secrets (keys, passwords, tokens) and values
  that identify the lab on the internet or the tailnet (domains, public IPs,
  tailnet IPs and names) are references (`${VAR}`, or a `secrets:` file).
  Everything else is written in the file as it is — ports, paths, node names,
  tuning — so a deploy needs as few environment variables as possible. A
  change to such a value goes through a pull request like any other change.
- `.env.example` — every variable the stack reads, with placeholders
  (`__PASTE_ONCE__`) and a comment saying where the real value lives in OpenBao.
- `README.md` — only if the app needs more than the inventory row says: data
  location, ports, quirks.
- `host/` — only if the stack needs something on the host that the container
  manager cannot run: scripts and systemd units installed by hand, with the
  steps in the app's `README.md` (`vps/openbao/host/` renews OpenBao's
  certificate).

## Rules

- No real `.env` files; `.env` is git-ignored and the scan blocks secrets.
- CI runs `docker compose config` on every compose file here
  (`decisions/pull-request-gate.md`).
- Moving a stack in is a plan, not a drive-by: old copy keeps running until
  the new one is healthy (`plans/migration.md`).

## Apps

- `vps/openbao/` — the secret store; defined, not deployed.
- `vps/hermes-webui/` — a second Hermes WebUI for someone without lab access;
  deployed on the VPS 2026-10-27, its WebUI image pinned to `0.52.561` for the
  agent-install fix (the README there owns the version and the one-time agent
  step).
