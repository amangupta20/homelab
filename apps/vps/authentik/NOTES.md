# Authentik — notes

The sources, reasons, tests and gotchas behind `README.md`.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| Authentik's `docker-compose.yml` (`goauthentik.io/docker-compose.yml`) | `2026.8.5`, 2026-11-10 | image, `server` and `worker` commands, `shm_size`, `/data`, the `AUTHENTIK_POSTGRESQL__*` variables |
| Authentik's configuration docs (`website/docs/install-config/configuration/configuration.mdx`) | tag `version/2026.8.5`, 2026-11-10 | `AUTHENTIK_WEB__BASE_URL`, the pooler section ("Use a PostgreSQL connection pooler"), `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` defaults, error reporting off by default |
| Authentik's `lifecycle/ak` and `lifecycle/container/Dockerfile` | tag `version/2026.8.5`, 2026-11-10 | the health check (`ak healthcheck`, as the image's own `HEALTHCHECK`, with a faster `start_interval`); what the root start does; `TMPDIR=/dev/shm/`, the reason for `shm_size` |
| Dokploy's template (`blueprints/authentik/` in `Dokploy/templates`) | commit `084d1cb15f`, 2026-10-15 | the worker starting after the server, to avoid a race filling the fresh `/data` volume |
| `ghcr.io/goauthentik/server` | `2026.8.5`, 2026-11-10 | arm64 image (`docker buildx imagetools inspect`) |

Choices that differ from the sources:

- **No bundled Postgres.** The database is `authentik` on the shared cluster, through `pg-proxy:5432`
  (`apps/vps/pg-proxy/`) to PgBouncer in **session** mode (`ansible/pigsty/pigsty.yml.template`). Authentik keeps
  everything in Postgres, including its task queue, and holds `LISTEN` connections and session advisory locks.
  Its docs say transaction pooling silently breaks those unless a second, direct endpoint is set; session mode
  does not, so no `AUTHENTIK_POSTGRESQL__DIRECT__*` is set. `CONN_MAX_AGE` stays at its default `0`, the docs'
  advice for session pooling. Why shared and not bundled: the cluster's B2 backups have a tested restore, and the
  tailnet round trip from pigsty-1 to the Dokploy VPS is 1 ms over a direct path (`tailscale ping`, 2026-11-10).
  The cost: SSO is down whenever pigsty-1 is.
- **No Docker socket, and the worker does not run as root.** Upstream mounts `/var/run/docker.sock` into the worker
  so Authentik can create outpost containers itself, and starts it as root only to join the socket's group and
  `chown` `/data`, then drops to the `authentik` user (`lifecycle/ak`). Access to the socket is root on the VPS, and this is
  the most exposed service on it. Without the socket, the embedded outpost inside `server` still serves forward-auth
  for every app; any other outpost (LDAP, RADIUS, a proxy elsewhere) is a small Compose service deployed by hand once,
  with a token made in the admin interface. Without root, the `chown` is skipped; a fresh named
  volume takes the image's ownership (uid 1000). On the first deploy both containers came up healthy without it.
- **`shm_size: 512mb` kept.** The image puts its temporary files in `/dev/shm`, and Docker's default is 64 MB.
  It is a ceiling, not memory set aside.
- **No published ports, no port 9443.** Traefik reaches port 9000; TLS ends at Traefik.
- **Three routers instead of one domain** (next section).
- **No `custom-templates` or `certs` volumes.** Nothing uses them yet.
- **Never asleep.** The owner turned Sablier off for it (2026-11-10): forward-auth checks call the container
  directly, so they would not wake it.

## Public login, tailnet-only admin

| Hostname | Who reaches it | What it serves |
|---|---|---|
| `AUTHENTIK_DOMAIN` | anyone; Let's Encrypt over HTTP-01 | everything except the paths below |
| `AUTHENTIK_DOMAIN`, paths `/if/admin`, `/if/flow/initial-setup`, `/api/v3/flows/executor/initial-setup` and `/setup` | nobody: 403 | — |
| `AUTHENTIK_ADMIN_HOST` | the tailnet only (`100.64.0.0/10`, as `apps/vps/pgadmin/`); DNS-only record to the VPS's tailnet address, zone wildcard certificate | everything |

- The **first-start setup** (`/if/flow/initial-setup/`), which sets the `akadmin` password, is refused publicly so
  nobody else can claim the instance between the deploy and the owner's first visit. Do it on the admin hostname.
  The page alone is not enough: it runs through the flow API, and 2026.8 redirects `/` to `/setup` before setup,
  so all three are refused (first deploy, 2026-11-10). After setup Authentik refuses the flow itself: the public
  API answered with its access-denied step (`curl`, 2026-11-10).
  No bootstrap password is set in the environment for the same reason the docs warn against it: it would sit in
  plain text in the container's environment.
- **This blocks the admin pages, not admin rights.** The API (`/api/v3/`) has to stay public, because the login
  flows and the user interface use it. So superusers are also refused at sign-in outside the tailnet (next section).

## Set in Authentik, not in this repo

These live in Authentik's database. Set through its API on 2026-11-10, with the owner's token (OpenBao
`kv/general/authentik`, field `api`; it acts as `akadmin` and has an expiry date).

- **Recovery:** a blueprint instance of the example `flows-recovery-email-mfa-verification.yaml`, which makes
  `default-recovery-flow`, set as the default brand's recovery flow and as the `recovery_flow` of the stage
  `default-authentication-identification` (that is what puts the link on the login page). A `PATCH` of that stage
  with only `recovery_flow` is refused ("at least one source must be selected"); send its `user_fields` and
  `sources` with it. The owner's test reset on 2026-11-10 sent the mail, and the link was used (event log).
- **Superusers sign in from the tailnet only:** expression policy `superuser-outside-tailnet` (passes for a pending
  user who is a superuser and whose `ak_client_ip` is outside `100.64.0.0/10`), gating the deny stage
  `deny-superuser-outside-tailnet`. It is bound at order 25 in `default-authentication-flow` (after the password,
  before the second factor) and at 15 in `default-recovery-flow` (before the mail is sent). Verified 2026-11-10:
  the recovery flow on the public domain, as `akadmin`, stopped at the deny stage and sent no mail. Authentik sees
  the real client address: the owner's logins were logged with a tailnet address.
- `akadmin` has a TOTP device.
- **Applications** (2026-11-18): `langfuse`, `artifact-keeper` and `cache-grafana` (unused since Grafana left cache-1 on 2026-11-22; the last two:
  `apps/homeserver/artifact-keeper/NOTES.md`, "Sign-in"). Group `homelab-admins` (the owner's everyday account) makes its members admins in the apps that map groups to roles; it grants no access by itself.
- **The API token** in OpenBao (`kv/general/authentik`, field `api`) expires; the one from 2026-11-10 had, and the
  owner replaced it on 2026-11-18. The same entry's field `domain` holds the public hostname, for code that needs it.
- **Every user may use every app, unless an app is restricted** (owner, 2026-11-10: "give default users access to
  all the apps since that was the point of SSO, unless I restrict some apps"). Authentik already works this way: an
  application with no policy binding is open to every user. To restrict an app, bind a group (or a policy) to its
  application; then only the bound group gets in. Restricted on 2026-11-20: `hermes-webui-1` (groups `hermes-webui-1`
  and `homelab-admins`), `pgadmin` and `cloudbeaver` (`homelab-admins`, as database admin tools); see each app's
  NOTES.md, "Sign-in".
- **Embedded outpost** (forward-auth, used by `cloudbeaver` only): its `authentik_host` is the public login domain, set
  on 2026-11-20. It was the tailnet-only admin hostname, and the outpost sends browsers to that host, so a sign-in
  there met an `akadmin` session and was refused by the group binding. `authentik_host_browser` did not change where
  the embedded outpost redirects, even after a restart of the server container.
- **Invite-only sign-up:** the enrollment flow `invite-enrollment` (stages, in order: invitation, with "continue
  without invitation" off; a form for username, name, email and password, checked by
  `default-password-change-password-policy`; create the user as an active internal user, in no group; log in). It is
  not linked from the login page, so the only way in is an invitation link. Tested 2026-11-10 on the public domain
  through the flow API: without an invitation it answered "Invalid invite/invite not found"; with a single-use one
  it created the user, who had access to `langfuse` (`check_access`), and the invitation was used up. The test user
  and invitation were deleted.

  To invite someone: on the admin hostname, **Directory → Invitations → Create**, flow `invite-enrollment` (not
  `default-source-enrollment`, which is listed too but is for external sources and answers "Flow does not apply to
  current user"), single use, an expiry date. Open the link in a private window: the flow refuses anyone already
  signed in. Copy the link and send it yourself; Authentik does not mail invitations. A new user
  has no second factor until they add one at `/if/user/`; nothing forces it yet.

Use a separate, non-admin account for signing in to apps: `akadmin` is refused everywhere outside the tailnet. An
invitation is the way to make that account.

## Email

Through Resend's SMTP server (`smtp.resend.com`, port 465, implicit TLS, user `resend`), from the mail subdomain
that Resend had already verified for Mattermost. The key is Authentik's own, named `authentik` in Resend, with
sending access to that one domain (made through Resend's API, 2026-11-10; SMTP login answered `235`). The account's
full-access key, used only to make it, is in OpenBao at `kv/general/resend`, field `apikey`.

Used for password recovery and Authentik's notifications. Recovery is the example blueprint
`flows-recovery-email-mfa-verification.yaml`, set as the brand's recovery flow: it asks for the second factor as
well as the emailed link, so access to the mailbox alone does not reset the `akadmin` password. The owner's test
reset on 2026-11-10 went through.

## Dates

When the facts in `README.md` were true from, or were checked.

- Running since 2026-11-10; the owner chose Authentik that day.
- The Pigsty role and database commands in step 1 ran on 2026-11-10.
