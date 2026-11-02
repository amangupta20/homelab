---
name: configure-prime-reviewer
description: Add a repository to the shared Prime reviewer, change its per-repository playbook or settings, or validate changes to the composite action without mixing private prompts with public code.
---

# Configure the Prime reviewer

**Status:** UNTESTED draft; proposed 2026-11-03. Offline checks below were
run during the folder migration; enrolling a second repository and the live
composite action have not been tested end to end.

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
   and two secrets named in the action's README. Fetch credentials through
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
8. **UNTESTED live validation:** after the caller merges, run a review on an
   owner PR. Check the unchanged required job name, checked fix commits,
   suggestions and replies. In private state, confirm a namespaced session,
   repository-tagged trace and a lesson proposal limited to allowed files.

## Gotchas

- Repository folders share one core on `main`; use branches for state and
  experiments. Do not duplicate the core on a branch for every repository.
- Old homelab sessions use `sessions/pr-<n>/`. The new action restores them
  as a fallback and writes `sessions/homelab/pr-<n>/` next time. Keep old data
  until that restore has been proven; never claim migration from a passing
  offline test alone.
- The public action can be inspected independently. Its README marks live
  behavior untested until the first composite-action run.
- Preserve the existing check and App installation scope unless the owner
  authorizes enrolling additional repositories.
