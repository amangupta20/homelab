# A change merges only after static checks, a secret scan, an AI review, and a pasted plan

Decided: 2026-10-26. Status: in force, enforced on GitHub.

## Why

Nothing in CI can reach Xen Orchestra, and it should not hold a credential
for it. So CI checks what it can see statically, and the one check that needs
the real lab — `tofu plan` — is produced by hand on a tailnet machine and
pasted into the pull request for review.

A pull request is blocked unless:

- `tofu fmt -check`, `tofu init -backend=false`, `tofu validate` and `tflint`
  pass on `iac/` (`.github/workflows/ci.yml`),
- every compose file in the repo passes `docker compose config` (same file),
- gitleaks passes over the full history (`.github/workflows/secret-scan.yml`),
- an AI reviewer finds no blocker on public exposure or lab safety
  (sections 1 and 5 of `repo/review.md`, `.github/workflows/prime-review.yml`);
  its other findings and `needs_owner` are reported for the owner and do not
  fail the check (changed 2026-10-26: the reviewer kept blocking on wording
  and on owner-only edits the owner approves anyway),
- the summary and resource actions of a `tofu plan` from the one checkout that
  applies (see `iac/README.md`) are pasted into the pull request, and one review
  approves it. The full plan stays out, because this repo is public (proposed
  2026-11-05).

## Addendum 2026-11-02: the Prime reviewer runs the `ai review` check

The owner replaced the single-call reviewer (`review.yml`, which sent the
diff to a model once) with the Prime reviewer (`repo/prime-reviewer.md`): an
agent that reads the repo around the diff, pushes mechanical fixes and posts
suggestions. The check keeps its name, so the ruleset is unchanged. It runs
only on the owner's pull requests: on anyone else's, including an agent's own
GitHub account, `ai review` fails with "not reviewed", and the owner merges
it after reviewing it by hand. It also takes minutes per push instead of
about one and a half.

## Addendum 2026-11-06: a clean Prime review gives the approval

The owner is the only person reviewing here and cannot approve their own pull
request, so the required approval meant using the bypass on every merge, which
also hid the cases where something had actually been flagged. The owner chose to
let the Prime reviewer's App approve a commit whose review is clean, over
dropping the approval requirement, so that the bypass now marks an exception:
`needs_owner` or a failed run. The approval is only as strong as the `ai review`
check, and the owner's merge remains the real review. Last-push approval was
turned off because the App may push the last commit. How it works, and what is
untested: `repo/prime-reviewer.md`.

## Cost / what this rules out

- The AI review costs a model call per push to a pull request, and it is
  only as good as a cheap model reading a checklist: it catches what a regex
  cannot, and it can be wrong or talked into approving by text in the diff.
  It is a gate in front of the owner's review, not a replacement for it.
- `tofu init -backend=false` skips the backend block, so a typo in
  `iac/backend.tf` only shows up at the first real `tofu init`.
- Enforced by the GitHub ruleset "protect main" (set 2026-10-26): no direct
  pushes, force-pushes or deletion of `main`; a pull request with one approval
  (re-approval after any new push, no last-push approval since 2026-11-06); and
  the checks `opentofu (fmt, validate,
  tflint)`, `compose config`, `gitleaks (full history)` and `ai review` must
  pass.
- GitHub does not let anyone approve their own pull request, so the owner's
  own changes merge on the Prime reviewer's approval (addendum above), or through
  the admin bypass when it did not approve. The bypass only works through a pull
  request — the checks still run and show, but the owner can choose to merge
  past a red one. An agent with its own GitHub account has no bypass: its
  change needs the owner's approval and every check green.

## Where it lives

`.github/workflows/`, `iac/.tflint.hcl`, `mise.toml`, `repo/secret-scanning.md`.
