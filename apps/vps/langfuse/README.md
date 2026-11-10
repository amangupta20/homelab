# Langfuse

**Status:** running on the VPS since 2026-11-10 (`journal/2026-11-10-deploy-langfuse.md`). The AI reviewer's trace
viewer and the place to learn evaluation on (`plans/ai-reviewer-prime-agent.md`, step 6; the owner chose Langfuse on
2026-11-10). The owner signed in and made the reviewer's organisation, project and API keys on 2026-11-10; one
probe trace went through end to end ("Sending traces"). No real traces yet, and ClickHouse has no backup.

## Derived from

| Source | Version read | What was taken |
|---|---|---|
| Langfuse's `docker-compose.yml` (`langfuse/langfuse`, `main`) | for release `v4.77.0`, 2026-11-10 | the services, images, ClickHouse and Redis settings, the variable names |
| Langfuse's `web/src/env.mjs`, `worker/src/env.ts`, `web/src/server/auth.ts` | tag `v4.77.0`, 2026-11-10 | the `AUTH_AUTHENTIK_*` provider and its issuer format; `AUTH_DISABLE_USERNAME_PASSWORD`; that `AUTH_DISABLE_SIGNUP` also refuses new SSO users; `TELEMETRY_ENABLED` |
| Langfuse's `web/Dockerfile`, `web/src/pages/api/public/health.ts`, `worker/src/features/health/` | tag `v4.77.0`, 2026-11-10 | the health routes, and that the images ship `wget` for health checks |
| Dokploy's template (`blueprints/langfuse/` in `Dokploy/templates`) | commit `bbd0817b9d`, 2026-08-09 | `HOSTNAME=0.0.0.0` for the web container |
| `docker.langfuse.com/langfuse/langfuse` and `langfuse-worker` `4.77.0`, `clickhouse/clickhouse-server` at the tag in `compose.yaml`, `redis` `7.4.7` | 2026-11-10 | arm64 images (`docker buildx imagetools inspect`) |

Choices that differ from the sources:

- **No bundled Postgres.** The database is `langfuse` on the shared cluster through `pg-proxy:5432`
  (`apps/vps/pg-proxy/`), PgBouncer in **session** mode as for Authentik, because Prisma's migrations take
  session-level locks. Same reasons and cost as `apps/vps/authentik/README.md`: tested backups, and Langfuse is
  down whenever pigsty-1 is.
- **No MinIO: a private Backblaze B2 bucket** (owner, 2026-11-10). Chainguard's free MinIO image is only published
  as `latest`, so it cannot be pinned, and B2 keeps the raw event files offsite. Its key reaches that bucket only.
  Each event batch is one upload over the internet; at one reviewer's volume the cost is cents a month (a guess).
  Media uploads from the browser would need a CORS rule on the bucket; nothing here sends media, so none is set.
- **No AI gateway.** It is new in v4.75 and optional; the reviewer does not route its model calls through Langfuse.
- **Sign-in through Authentik only.** See "Sign-in".
- **Public**, owner's choice of 2026-11-10, so that an importer can send traces from anywhere. The ingestion API
  needs a project key; the UI needs an Authentik login.
- **Asleep when idle, behind Sablier,** 20 minutes like Blinko (owner, 2026-11-10: "if it causes any issues we can
  move back to always on"). All four containers are the group `langfuse`, so they stop and start together.
- **ClickHouse and Redis on a network of their own**, not on `dokploy-network`, and no ports published at all.
  Upstream binds them to the host's localhost instead.
- **ClickHouse capped at 4 GB** of memory, a guess (compose comment); its user name is `langfuse`, not `clickhouse`.
- **A Redis health check that logs in.** Upstream's `redis-cli ping` without the password gets an error reply and
  still exits 0.
- **Telemetry off.**

## Sign-in

Through Authentik's OIDC, with Langfuse's built-in Authentik provider: in Authentik, an OAuth2/OpenID provider and
an application with the slug `langfuse` (the issuer is `https://<authentik domain>/application/o/langfuse/`), the
redirect URI `https://<langfuse domain>/api/auth/callback/authentik` (strict), the implicit-consent authorization
flow, scopes `openid`, `email` and `profile`, grant types `authorization_code` and `refresh_token`, and the client ID
and secret into OpenBao. A provider made through the API gets an empty `grant_types` list, and Authentik then refuses
every sign-in with "Invalid grant_type for provider" (Langfuse shows "The request is otherwise malformed"; first
sign-in, 2026-11-10). Made through Authentik's API
on 2026-11-10; the sign-in button leads to Authentik's authorize page with that redirect URI (`curl`). The owner's first sign-in through Authentik
worked on 2026-11-10 (a user row in Langfuse's database; the organisation, project and keys were made later that day).

Password logins are off, so the sign-up page offers only Authentik. A first Authentik login creates the Langfuse
account. `AUTH_DISABLE_SIGNUP` is not set because it refuses that too (`auth.ts`, `createUser`). So **who may use
Langfuse is decided in Authentik**, and by the owner's rule every Authentik user may use every app unless it is
restricted (`apps/vps/authentik/README.md`). The `langfuse` application has no binding (the `langfuse-users` group it
had at first was removed on 2026-11-10). A new Langfuse account sees no organisation or project until someone adds
it to one, because `LANGFUSE_DEFAULT_ORG_ID` is not set. To restrict Langfuse to a group, bind that group to the
application in Authentik.

`akadmin` cannot sign in here from outside the tailnet (Authentik refuses superusers there); use a non-admin account.

Checked on the public domain, 2026-11-10: `POST /api/auth/signup` answers 422 "Sign up with email and password is
disabled for this instance", and a password login answers 401.

## Sending traces

- **OpenTelemetry only.** Langfuse 4.77 runs in `events_only` mode: `POST /api/public/ingestion` takes scores only
  and answers 400 for `trace-create` and `span-create`; traces go to `POST /api/public/otel/v1/traces` (OTLP, JSON
  or protobuf) and are read back with `GET /api/public/v2/observations?traceId=...`; `/api/public/traces/<id>`
  answers 404 for reads but still deletes. Basic auth with the project's public and secret key.
- The reviewer project's keys are in OpenBao at `kv/general/langfuseprime`, fields `publickey` and `secret_key`
  (owner, 2026-11-10).
- Tried 2026-11-10 with a two-span OTLP JSON trace: accepted (200), both spans read back within seconds, one 821-byte
  event file under `events/otel/` in the B2 bucket. Deleting the trace removed it from Langfuse, but the event file
  was still in B2 30 s later and was deleted by hand. Whether Langfuse cleans these up later is not known.

## Asleep when idle

How it works: `apps/vps/sablier/README.md`. What is different here:

- A wake starts ClickHouse, Redis, web and worker together; Sablier answers once all four are healthy. Twice on the
  VPS (2026-11-10, all four stopped by hand, then one `GET` through the public domain): 35 s and 27 s, no container
  restarted. On the workstation web restarted once ("Tried on the workstation"), so that can still happen.
- **The first answer after a wake is `302` to the same path**, not the page itself; the request after it gets the
  real answer. A client following that redirect for a `POST` would usually resend it as a `GET`, so the importer
  should wake Langfuse with a `GET /api/public/health` (following redirects) before it sends traces.
- The worker sleeps too, so evaluations that a model runs on new traces, and Langfuse's other background jobs, run
  only while someone uses it. Traces sent to the API wake it, and the worker works through them while awake.
- Back to always on: remove the router's `middlewares=langfuse-sablier` label and every `sablier.*` label, then
  redeploy.

## Deploying

1. Pigsty: put the role's password in OpenBao (`kv/general/pigsty`, field `pg_user_langfuse`; letters and digits,
   because it goes into a URL), run `ansible/pigsty/render.sh`, then on the node `bin/pgsql-user pg-meta langfuse`,
   `bin/pgsql-db pg-meta langfuse` and `bin/pgsql-user pg-meta dbuser_owner` (done 2026-11-10, each `failed=0`).
2. B2: a private bucket and an application key for that bucket only, read and write (made by the owner in B2's
   console, 2026-11-10). No key in OpenBao can make keys.
3. Authentik: the provider, application and policy binding in "Sign-in".
4. OpenBao: the fields of `.env.example` at `kv/dokploy/langfuse`.
5. Dokploy: a Compose service from this repo's `main`, path `apps/vps/langfuse/compose.yaml`, no domain set in
   Dokploy (the routers are labels here), environment from OpenBao, and the project added to the OpenBao
   provider's assignments (`systems/openbao.md`). The domain goes under `*.app.<zone>`, the DNS-only wildcard to
   the VPS, as `langfuse.app.<zone>`; a name directly under the zone hits the Cloudflare-proxied wildcard and got
   522 (2026-11-10).
6. The first Authentik login, then an organisation, a project and its API keys for the importer.

## Backups

- Postgres (users, projects, API keys, prompts, data set definitions): in the shared cluster's backups
  (`systems/backups.md`). Restoring it needs `LANGFUSE_SALT` and `LANGFUSE_ENCRYPTION_KEY` from OpenBao.
- The B2 bucket: the raw event files, kept by B2 itself; no second copy.
- **ClickHouse (traces, observations and scores): no backup.** Traces can be imported again from the reviewer's run
  archives in B2, but hand-made scores and annotations live only here. A ClickHouse backup (its `BACKUP` command to
  S3, for example) is needed before the evaluation's hand-marking stage starts (plan, step 6).
- Redis holds queues only; losing it loses jobs in flight.

## Tried on the workstation

On 2026-11-10, on the x86-64 workstation (not the ARM VPS), with this compose file plus a throwaway `postgres:18`
container named `pg-proxy` and placeholder values for everything else; B2 and Authentik were not reached.

- All four containers became healthy; Prisma applied its 470 migrations and ClickHouse its own on the first start.
  The worker logged missing-table errors while web was still migrating, then ran normally.
- `/api/public/health` answered `{"status":"OK","version":"4.77.0"}`. `/api/auth/providers` lists `authentik` and
  still lists `credentials`: with `AUTH_DISABLE_USERNAME_PASSWORD` the password provider stays registered and refuses
  every login in its `authorize` (`auth.ts`). Not tried with a real login.
- The worker's health check failed until it had `HOSTNAME=0.0.0.0` too (it listened on the container's hostname).
- Memory while idle and awake: worker 734 MB, web 410 MB, ClickHouse 227 MB, Redis 8 MB (`docker stats`).
- A Sablier-style cold start, all four stopped and then started together with `docker start`: all healthy after 14 s,
  web restarted once because ClickHouse was not up yet. On the VPS's ARM CPU it may be slower.

## Things to watch

- Memory under load. Just after the first start on the VPS: worker 620 MB, ClickHouse 359 MB, web 241 MB, Redis 9 MB
  (`docker stats`, 2026-11-10).
- The idle stop after 20 minutes is not observed yet, and whether the first request after a redeploy gets 500 (the
  Sablier rename issue in its README).
- `pg-proxy` closes connections idle for 30 minutes; with the stack asleep after 20 that should not matter.
