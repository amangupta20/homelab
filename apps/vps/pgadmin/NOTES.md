# pgAdmin — notes

## Sources

What `README.md`'s stack was derived from.

| Source | Version read | What was taken |
|---|---|---|
| pgAdmin's container docs (`docs/en_US/container_deployment.rst`) | `REL-9_19`, 2026-11-09 | the `PGADMIN_*` variables, `/var/lib/pgadmin`, `/pgadmin4/servers.json`, port 80 |
| `dpage/pgadmin4` on Docker Hub | `9.19.0`, 2026-11-09 | arm64 image |
| pgAdmin's OAuth2 docs (`docs/en_US/oauth2.rst`, `user_management.rst`), `web/config.py`, `web/pgadmin/authenticate/oauth2.py` | `REL-9_19`, 2026-11-20 | OIDC through one `PGADMIN_CONFIG_OAUTH2_CONFIG` list, `OAUTH2_ADDITIONAL_CLAIMS`, callback `/oauth2/authorize`, `PROXY_X_PROTO_COUNT = 1` (so the callback is https behind Traefik), accounts per sign-in source |

## Sign-in

In Authentik (API, as `akadmin`): an OAuth2/OpenID provider and application `pgadmin` with the settings of Langfuse's
provider (`apps/vps/langfuse/NOTES.md`, "Sign-in"), redirect URI `https://<pgAdmin host>/oauth2/authorize` (strict),
and a policy binding for `homelab-admins`. pgAdmin checks the `groups` claim for the same group
(`OAUTH2_ADDITIONAL_CLAIMS`). The client ID and secret are in OpenBao (`.env.example`).

pgAdmin keeps accounts from each sign-in source apart, even with the same email (`user_management.rst`, "Accounts from
different authentication sources"). The first Authentik sign-in creates a new, non-admin account
(`OAUTH2_AUTO_CREATE_USER`) without the server from `servers.json`, which is read for the first internal account only.
Add the server by hand (host `pg-proxy`, port `5436`, user `dbuser_owner`), or load it for that account with
`/venv/bin/python3 /pgadmin4/setup.py load-servers /pgadmin4/servers.json --user <email> --auth-source oauth2`
**UNTESTED**.

Checked locally on `9.19.0` with placeholder values: the config parses and the login page shows the Authentik button.

## Dates

When the facts in `README.md` were true from, or were checked.

- Running since 2026-11-09; the tailnet-only check with a throwaway router ran that day.
