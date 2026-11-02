# 2026-11-03 — moved reviewer state to B2 and tested restoration

**Who:** owner and Codex  **Scope:** Prime reviewer runtime storage and GitHub Actions secrets  **Mode:** write
**Task:** move PR sessions and traces to private B2, preserve replies and future trace import, select Muse Spark 1.3 Contributor
**Skill:** `skills/configure-prime-reviewer/`

## What changed

Verified the supplied bucket's private ACL and its application's one-bucket
restriction using B2 read-only S3 and Native API calls. Normalized the supplied
endpoint, derived its region, and saved the runtime fields at the agreed
OpenBao path. The original supplied record was preserved. Configured five
caller Actions secrets through `gh secret set` using stdin.

The migration uploaded two PR sessions and two trace bundles. Prompts and
lessons stay in their private Git repository. The selected Muse model passed
a local Prime smoke test; the private config was updated. The old live caller
retains its hardcoded model until the replacement workflow merges.

## Snapshot / backup taken

The clean Git state checkout at
`3297851510fa93871fbbb8256d581ca2cd4a2de5` is the source snapshot. Its remote
branch and all old sessions and traces remain intact. Existing legacy review
jobs were completed before this copy was imported. No source objects were
deleted.

## How it was verified

Ran migration preflight, then applied its object uploads. For PRs 29 and 30,
downloaded the saved session from B2 and compared every restored file's
SHA-256 with the source. Also downloaded each trace bundle and compared root
and child transcript contents. All comparisons passed.

Offline storage and integration checks passed in a transient process capped
at 512 MiB, 24 tasks and 30 seconds. Sources: `migrate_state.py` output,
read-only B2 checks and the capped unittest run on 2026-11-03.

## Still open

The replacement caller awaits merge. A new legacy review caused by the final
PR push must finish before a final state refresh; the migration tool can
refresh imported pointers but refuses to replace a native B2 review. Git
state stays available as rollback. No Phoenix, Langfuse or OpenObserve viewer
or live exporter has been deployed; the action's `observability.md` owns that
future import boundary.

## Continuation verification

A temporary copy of PR 30's B2-restored session was passed to Prime with `-c`
and the selected Muse Spark model. It read the existing 79-line session,
appended 13 lines, exited 0 and wrote the expected verification reply. This
copy was discarded, so the test did not alter saved PR state. The capped
process reported 149.9 MiB peak memory and a 6.479-second runtime. The final
24-test suite also covers refusal to overwrite a native B2 review during
migration. The GitHub comment-event path still awaits the caller merge.
