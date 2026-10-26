# A change merges only after static checks, a secret scan, and a pasted plan

Decided: 2026-10-26. Status: in force — enforcement incomplete (see below).

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
- a `tofu plan` from the one checkout that applies (see `iac/README.md`) is
  pasted into the pull request, and one review approves it.

## Cost / what this rules out

- `tofu init -backend=false` skips the backend block, so a typo in
  `iac/backend.tf` only shows up at the first real `tofu init`.
- **Not done yet:** branch protection and required status checks on `main`.
  The workflows exist; the repository settings that make them mandatory do not.

## Where it lives

`.github/workflows/`, `iac/.tflint.hcl`, `mise.toml`, `docs/secret-scanning.md`.
