---
id: repo-guardrails
type: module-design
title: repo-guardrails — secret scan and commit discipline
status: draft
parent: arch-homelab
---

# repo-guardrails

**Responsibility.** Stop the two mistakes that cannot be undone: committing a
secret, and making a change nobody can trace back to a reason.

**Owns.** `.githooks/`, `secret-scan.toml`, `.github/workflows/secret-scan.yml`,
`mise.toml`, and the rules in `AGENTS.md`.

**Boundary.** It cannot stop a commit made with `--no-verify`; it can only refuse
to push it. CI is detection after the fact, not prevention.

## Shape

- `git commit` scans staged changes with gitleaks and blocks on a finding.
- `git push` scans the commits the pushed ref carries and blocks on a finding.
- CI scans full history on every push and pull request, and is not yet a required
  check.
- The rules file is scanned like any other file: gitleaks exempts the exact path
  given as `-c`, so every scan hands it a temporary copy.
- One commit, one change; subjects in plain prose, present tense.

## Unconfirmed — research needed

- Whether the workflow becomes a required status check with branch protection.
  Nothing enforces it today.
- Whether `tofu fmt`/`validate` and tflint join this gate or get their own.
