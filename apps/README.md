# Apps — Compose stacks as code

Every container stack the lab runs in code, one folder each, by where it is deployed:

```
apps/homeserver/<app>/   on a home VM, by Ansible (`ansible/cache.yml`, `ansible/proxy.yml`)
apps/vps/<app>/          on the remote VPS, by Dokploy
```
Each app folder holds:

- `compose.yaml` — the stack. Secrets (keys, passwords, tokens) and values
  that identify the lab on the internet or the tailnet (domains, public IPs,
  tailnet IPs and names) are references (`${VAR}`, or a `secrets:` file).
  Everything else — ports, paths, node names, tuning — is written in the file,
  so a deploy needs few variables and a change goes through a pull request.
- `.env.example` — every variable the stack reads, with placeholders
  (`__PASTE_ONCE__`) and a comment saying where the real value lives in OpenBao.
- `README.md` — 40 lines at most: what it is, where it runs, its address,
  how you sign in (Authentik OIDC or forward-auth, or its own login), data,
  secrets, backups, and links to the foundation pages (never a copy).
  `NOTES.md` beside it holds the rest, uncapped: sources, choices, tests, gotchas.
- `host/` — only for what the container manager cannot run: scripts and
  systemd units installed by hand, steps in the app's README or `NOTES.md` (`vps/openbao/host/`).

## Rules

- No real `.env` files; `.env` is git-ignored and the scan blocks secrets.
- CI runs `docker compose config` on every compose file here
  (`agents/rules/pull-request-gate.md`).
- Moving a stack in is a plan, not a drive-by: old copy keeps running until
  the new one is healthy (`agents/plans/home-overhaul.md`).
- A homeserver stack whose images or apt sources come from an upstream the
  LAN cache does not know yet adds it first (`agents/skills/add-a-cache-remote/`);
  Docker Hub needs nothing. Its machine is a cache client (`ansible/README.md`,
  "Adding a host").

## Apps

The list of apps and their state is `lab/inventory/services.md`; each row links
its folder here.
