# Secret scanning

Every commit and every push is scanned for credentials, and so is the full
history in CI. The point is not mistrust of the OpenBao rule in the README —
it is that a secret pasted once at 1am is the mistake that cannot be undone by
deleting the file: git history keeps it, and a fork keeps it too.

## What runs, and when

| Moment | Command | Catches |
|---|---|---|
| `git commit` | `.githooks/pre-commit` -> `gitleaks git --staged` | a credential in the changes being committed |
| `git push` | `.githooks/pre-push` -> `gitleaks git --log-opts <range>` | a credential in any commit being pushed, including ones made with `--no-verify` |
| push / pull request | `.github/workflows/secret-scan.yml` | the same, over the whole history, on a machine with no hooks installed |

Rules live in `secret-scan.toml`: gitleaks' built-in ruleset, one extra rule that
matches AWS key IDs without needing a nearby keyword, and a short list of
allowlisted placeholder patterns.

The file is not named `.gitleaks.toml` on purpose. gitleaks' own default
config excludes every path matching `gitleaks\.toml` from scanning, and it never
scans the file handed to it as `-c` — so a rules file under that name would be
the one file in the repo no scan could see. Named `secret-scan.toml`, it escapes
the first exclusion, and both hooks give it a second pass with a throwaway copy
as the config to close the second.

## Setup (once per checkout)

```bash
mise install            # installs the pinned gitleaks
mise run hooks:install  # git config core.hooksPath .githooks
```

`core.hooksPath` is per-clone, not per-repo, so the second command is the one
people forget. CI is the backstop when they do.

Manual scan of everything: `mise run scan`.

## Placeholders

Documentation shows the shape of a value, never the value. Use
`__PASTE_ONCE__` or `<placeholder>` — both are allowlisted, so docs do not trip
the scanner. A real-looking example (a live-format key, even a dead one) is
indistinguishable from a leak and will be treated as one.

## When it fires

1. **Rotate first.** Delete-then-commit leaves the value in history, and in
   every clone and CI log that already fetched it. Rotate in OpenBao.
2. Rewrite the offending commit (`git rebase -i`, or `git reset` if not pushed)
   so history never carried it.
3. If it was pushed: rotate, rewrite, force-push, and check whether a fork or
   CI artefact kept a copy.

`gitleaks:allow` inline comments and `--no-verify` are for a reviewed false
positive only. A real block gets fixed, not waived.
