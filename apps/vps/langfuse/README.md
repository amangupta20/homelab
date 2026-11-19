# Langfuse

**Status:** running on the VPS since 2026-11-10 (`agents/journal/2026-11-10-deploy-langfuse.md`). The AI reviewer's trace
viewer and the place to learn evaluation on (`agents/plans/ai-reviewer-prime-agent.md`, step 6; the owner chose Langfuse on
2026-11-10). The owner signed in and made the reviewer's organisation, project and API keys on 2026-11-10; one
probe trace went through end to end (`NOTES.md`, "Sending traces"). The reviewer's runs are imported by the stack's `importer`
service since 2026-11-11 (`NOTES.md`, "Importer"); ClickHouse has no backup.

## Backups

- Postgres (users, projects, API keys, prompts, data set definitions): in the shared cluster's backups
  (`lab/systems/backups.md`). Restoring it needs `LANGFUSE_SALT` and `LANGFUSE_ENCRYPTION_KEY` from OpenBao.
- The B2 bucket: the raw event files, kept by B2 itself; no second copy.
- **ClickHouse (traces, observations and scores): no backup.** Traces can be imported again from the reviewer's run
  archives in B2, but hand-made scores and annotations live only here. A ClickHouse backup (its `BACKUP` command to
  S3, for example) is needed before the evaluation's hand-marking stage starts (plan, step 6).
- Redis holds queues only; losing it loses jobs in flight.

## Things to watch

- Memory under load. Just after the first start on the VPS: worker 620 MB, ClickHouse 359 MB, web 241 MB, Redis 9 MB
  (`docker stats`, 2026-11-10).
- A Langfuse tab left open keeps the stack awake: it polls `/api/auth/session` about every 5 minutes, which renews
  Sablier's 20-minute session. From 12:00 to 17:00 UTC on 2026-11-10 there were 12 to 14 such requests an hour
  and no other traffic (Traefik's access log), and the stack never slept. Close the tab to let it sleep.
- The idle stop after 20 minutes is not observed yet, and whether the first request after a redeploy gets 500 (the
  Sablier rename issue, `apps/vps/sablier/NOTES.md`).
- `pg-proxy` closes connections idle for 30 minutes; with the stack asleep after 20 that should not matter.

Everything else, word for word, is in `NOTES.md`: "Derived from", "Sign-in", "Sending
traces", "Importer", "Asleep when idle", "Deploying", "Tried on the workstation".
