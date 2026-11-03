---
name: configure-prime-reviewer
description: Add a repository to the shared Prime reviewer, change its per-repository playbook or settings, or validate changes to the composite action without mixing private prompts with public code.
---

# Configure the Prime reviewer

**Status:** UNTESTED draft; proposed 2026-11-03. Offline checks below were
run during the folder migration. The composite action with B2 storage has
run live once, a review on homelab PR 31 (2026-11-03); enrolling a second
repository and a live `/prime` reply have not been tested.

## When to use

For repository onboarding or changes spanning the public action, private
configuration and a caller workflow. The current homelab behavior is owned by
`repo/prime-reviewer.md`; the action's README owns its inputs and examples.

## How

1. Inspect the caller workflow and the current private configuration before
   editing. Keep credentials, prompts and traces out of the public action.
   Source: the owner's folder-layout request, 2026-11-02, and the action and
   configuration migration diffs, 2026-11-03.
2. In the private config repository, create `repos/<repo>/config.toml` and
   `repos/<repo>/playbook/SKILL.md`. Start from homelab's folder, then replace
   its rules, protected paths, blocking sections, model and trusted check.
   Repository conventions belong in its playbook; common lessons belong in
   `skills/common-review/SKILL.md`. The shared core stays owner-controlled.
3. Keep the playbook inside that repository's folder. The action requires
   explicit `rules`, `protected`, `blocking_sections` and `fix_check` settings;
   empty check or section values are an intentional opt-out. Checks run in
   the PR checkout using trusted code from `$RULES_DIR`. Do not execute a
   check script that the pull request changed.
4. **UNTESTED onboarding:** install the review App on the target repository
   and private config repository under the same owner. In the target's
   Settings → Secrets and variables → Actions, configure the App ID variable
   and two secrets named in the action's README, plus the five B2 secrets
   when the caller sets `state-backend: b2` (see "Runtime state in B2"). Fetch credentials through
   OpenBao; never put values in files or chat.
5. Copy the action's example caller workflow. Preserve the owner's triggers,
   concurrency and the `ai review` job name when it is a required check. Add
   toolchain setup before the action when needed. A `config-ref` input can
   select an experimental private branch; lesson proposals target that ref.
6. Run these from the action checkout (executed during migration):
   ```sh
   python3 -I -m unittest discover -s tests -v
   ```
   From homelab, check its caller and page properties (executed):
   ```sh
   mise x actionlint@1.7.12 -- actionlint .github/workflows/prime-review.yml
   python3 -I .githooks/check-properties.py
   ```
7. Review across all three repositories before pushing: an action release
   must exist before a caller references it, and the private configuration
   must support the installed caller while a replacement waits for merge.
8. **Live validation:** after the caller merges, run a review on an owner
   PR (done for homelab: PR 31, review mode; the reply path is UNTESTED). Check the unchanged required job name, checked fix commits,
   suggestions and replies. In private state, confirm a namespaced session,
   repository-tagged trace and a lesson proposal limited to allowed files.

## Gotchas

- Repository folders share one core on `main`; use branches for state and
  experiments. Do not duplicate the core on a branch for every repository.
- With the Git backend (no B2 inputs), old homelab sessions use
  `sessions/pr-<n>/`; the action restores them as a fallback and writes
  `sessions/homelab/pr-<n>/` next time. With B2, sessions live under
  `sessions/<owner>/<repo>/<pr>/` in the bucket. Keep old data
  until that restore has been proven; never claim migration from a passing
  offline test alone.
- The public action can be inspected independently. Its README owns which
  of its behaviour has run live.
- Preserve the existing check and App installation scope unless the owner
  authorizes enrolling additional repositories.

## Runtime state in B2

The B2 implementation and migration helper live in the public action repo;
credentials live at `kv/general/prime-reviewer-b2` in OpenBao. Use the five
named Actions secrets in the caller example, with `state-backend: b2` so
missing credentials fail explicitly. The model subprocess must never receive
B2 or GitHub credentials. Source: action integration and the live verification
in `journal/2026-11-03-prime-reviewer-b2-migration.md`.

Before cutover, wait for the last legacy Git-backed run, clone its clean
`state` branch, and use the action's `migrate_state.py` preflight. Its `--apply`
mode uploads sessions and traces and downloads them for content comparison.
`--refresh-imports` updates an earlier import after a later legacy run; it
refuses to replace state created by a native B2 review. Preserve Git state as
rollback. Do not silently start a new conversation when a reply has no session.

`observability.md` in the action owns the future importer boundary. Raw Prime
records are preserved for replay; they are not already OTLP. No viewer must
be reachable for reviews to work.

Run unfamiliar worker tests under memory, process and time limits. Inspect
subprocess calls first: a test must never launch a suite that includes itself.
The 2026-11-03 incident came from two such recursive test launchers; see
`journal/2026-11-03-recursive-reviewer-tests-oom.md`. A local bounded example
was run from the action checkout (temporary virtualenv prepared with `uv`):

```sh
systemd-run --user --pipe --wait --collect --property=MemoryMax=512M --property=TasksMax=24 --property=RuntimeMaxSec=30s --working-directory=/tmp /tmp/prime-reviewer-b2-venv/bin/python -I -m unittest discover -s "$PWD/tests" -v
```

B2 restoration and a temporary local Prime continuation passed, and homelab
PR 31 was a live review on B2. A live `/prime` reply remains the final
activation check; do not promote this whole onboarding skill out of UNTESTED
until that passes.
