# 2026-11-23 — Technitium's console behind Authentik at dns.home

**Who:** Claude Code, at the owner's request. **Scope:** `proxy-1`, Authentik.
**Mode:** write. **Task:** a name and sign-in for the DNS console. **Skill:** none.

## What changed

- Authentik, through its API: proxy provider `dns-home` (copied from `traefik-home`),
  application `dns-home` bound to `homelab-admins`, added to the outpost `home`.
- `proxy-1`: route `apps/homeserver/traefik/routes/dns.yml.j2` (`dns.home.<zone>` to
  the Pi's console on 5380, forward-auth), by `ansible-playbook proxy.yml`; then the
  outpost restarted (`docker compose restart authentik-outpost`).

## Snapshot / backup taken

None: both changes only add objects; removing the route file and the three
Authentik objects undoes them.

## How it was verified

- `--check --diff` showed only the new route file; applied with `changed=1`.
- Before the outpost restart, the name answered 400 ("no app for hostname"), so
  nothing reached the console. After it, `curl`: `/`, `/index.html` and
  `/api/user/session/get` answer 302 to Authentik's sign-in, also with a forged
  `X-authentik-username`; the certificate verifies; the outpost ping answers 204;
  `traefik`, `traefik-logs` and `goaccess` still answer 302.
- A browser sign-in by the owner: not yet.

## Follow-up (same day)

Technitium's own login replaced by sign-in through Authentik: OIDC client
`dns-console` in Authentik, set on the Pi by `ansible/oob.yml` (second run
`changed=0`). `/sso/login` redirects to Authentik with the right callback.
