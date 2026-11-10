# 2026-11-10 — deployed Langfuse as the reviewer's trace viewer

**Who:** the owner, with Claude Code  **Scope:** new Dokploy project `langfuse`, database `langfuse` on `pigsty-1`,
Authentik, a new B2 bucket  **Mode:** write
**Task:** step 6 of `plans/ai-reviewer-prime-agent.md`  **Skill:** `skills/deploy-on-dokploy/`

## What changed

- **Pigsty:** role and database `langfuse` (PgBouncer session mode), and the role added to `dbuser_owner`
  (`ansible/pigsty/pigsty.yml.template`). Before writing, `render.sh --check` with the template from before this
  change said the node matched it, so only Langfuse's lines changed. After `render.sh`, `bin/pgsql-user pg-meta
  langfuse`, `bin/pgsql-db pg-meta langfuse` and `bin/pgsql-user pg-meta dbuser_owner` each reported `failed=0`.
- **OpenBao:** `kv/general/pigsty` gained `pg_user_langfuse`; `kv/dokploy/langfuse` holds the stack's fields
  (`apps/vps/langfuse/.env.example`). The owner added the B2 fields under other names (version 2), which were
  renamed to the ones the stack reads, with the region and `https://` added (version 3).
- **B2:** the owner made a private bucket and a key limited to it, read and write, in B2's console. Checked with
  `b2_authorize_account`: the key names that bucket only; the bucket is `allPrivate` and was empty.
- **Authentik (API):** group `langfuse-users` with `akadmin`, OAuth2 provider `langfuse`, application `langfuse`, and
  a binding of the application to that group.
- **Dokploy (API):** new project and Compose service from this repo's `main` (`autoDeploy` off), environment as
  OpenBao references, and the project added to the OpenBao provider's assignments (23 after the change, token sent
  back as the mask).

## Snapshot / backup taken

None of the VPS: a new app that touches nothing existing, as for Authentik. Before the Pigsty change, the cluster's
last backup was checked: incremental from 01:00 on 2026-11-10, status `ok` (`pgbackrest info`).

## What went wrong

- **The first domain was wrong.** `langfuse.<zone>` falls under the zone's wildcard, which Cloudflare proxies, and
  answered 522. The other apps use `<app>.app.<zone>`, the DNS-only wildcard to the VPS. Moved to
  `langfuse.app.<zone>`, the Authentik redirect URI with it, and redeployed.
- **No key in OpenBao could make B2 keys.** `kv/general/tofub2` is limited to its own bucket, and `kv/dokploy/b2` (the
  Dokploy backup destination's key) has no `writeKeys`. The owner made the bucket and key instead.

## How it was verified

- Dokploy's deployment finished with `main`'s commit. All four containers healthy; Prisma reported every migration
  applied.
- `curl` on the public domain: `/api/public/health` 200 (`4.77.0`) with a Let's Encrypt certificate; HTTP redirects
  to HTTPS; `POST /api/auth/signup` 422 (password sign-up disabled); a password login 401; the Authentik sign-in
  leads to Authentik's authorize page with the strict redirect URI.
- Sablier: all four stopped by hand, then one `GET` through the public domain woke them in 35 s and, a second time,
  27 s, with no restart. The first answer is `302` to the same path (`apps/vps/langfuse/README.md`).

## Still open

- Nobody has signed in yet; the first login creates the account, then an organisation, a project and API keys.
- No ClickHouse backup; needed before hand-made scores start.
- The 20-minute idle stop is not observed yet.
- The importer for the reviewer's run archives (plan, step 6).

## Follow-up 2026-11-11: the importer

- **Changed:** the Langfuse stack was redeployed from `main` with the `importer` service (PRs #67/#68). Its
  variables come from `kv/dokploy/langfuse`: the reviewer's own B2 key (owner's choice over a read-only one) and the
  reviewer project's Langfuse keys, copied from `kv/general/langfuseprime`. The 76 runs then in B2 had been imported
  from the workstation the day before, with the same image and script.
- **Verified:** the service's first pass reached Langfuse through the public domain from inside the VPS, skipped
  the 76 runs already there ("already in Langfuse, not sent again"), and imported 5 new runs. `verify` on one of them
  matched the run's metadata (`apps/vps/langfuse/README.md`, "Importer").
- **Found:** the stack had not slept for about 10 hours. Traefik's access log showed only a browser tab's polling
  (12 to 14 requests an hour, mostly `/api/auth/session`), which keeps renewing Sablier's session. Not a fault.
- **Still open:** the ClickHouse backup (waits for Garage, owner); a failed run and a run with subagents, when they
  occur, to test those paths.
