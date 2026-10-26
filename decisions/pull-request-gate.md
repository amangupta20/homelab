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
  (sections 1 and 5 of `repo/review.md`, `.github/workflows/review.yml`);
  its other findings and `needs_owner` are reported for the owner and do not
  fail the check (changed 2026-10-26: the reviewer kept blocking on wording
  and on owner-only edits the owner approves anyway),
- a `tofu plan` from the one checkout that applies (see `iac/README.md`) is
  pasted into the pull request, and one review approves it.

## Cost / what this rules out

- The AI review costs a model call per push to a pull request, and it is
  only as good as a cheap model reading a checklist: it catches what a regex
  cannot, and it can be wrong or talked into approving by text in the diff.
  It is a gate in front of the owner's review, not a replacement for it.
- `tofu init -backend=false` skips the backend block, so a typo in
  `iac/backend.tf` only shows up at the first real `tofu init`.
- Enforced by the GitHub ruleset "protect main" (set 2026-10-26): no direct
  pushes, force-pushes or deletion of `main`; a pull request with one approval
  (re-approval after any new push); and the checks `opentofu (fmt, validate,
  tflint)`, `compose config`, `gitleaks (full history)` and `ai review` must
  pass.
- GitHub does not let anyone approve their own pull request, so the owner's
  own changes merge through the admin bypass, which only works through a pull
  request — the checks still run and show, but the owner can choose to merge
  past a red one. An agent with its own GitHub account has no bypass: its
  change needs the owner's approval and every check green.

## Where it lives

`.github/workflows/`, `iac/.tflint.hcl`, `mise.toml`, `repo/secret-scanning.md`.
