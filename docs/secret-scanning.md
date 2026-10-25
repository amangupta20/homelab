# Secret scanning

Every commit and every push is scanned for credentials, and so is the full
history in CI. The point is not mistrust of the OpenBao rule in the README —
it is that a secret pasted once at 1am is the mistake that cannot be undone by
deleting the file: git history keeps it, and a fork keeps it too.

## What runs, and when

| Moment | Command | Catches |
|---|---|---|
| `git commit` | `.githooks/pre-commit` -> `gitleaks git --staged` | a credential in the changes being committed |
| `git push` | `.githooks/pre-push` -> `gitleaks git --log-opts <pushed ref>` | a credential in any commit the pushed ref carries, including ones made with `--no-verify` |
| push / pull request | `.github/workflows/secret-scan.yml` | the same, over the whole history, on a machine with no hooks installed |

The local hooks are the only **prevention**. CI runs after the push, so a
leaked commit is already on the remote — and in the Actions log — by the time
it goes red. Treat CI as detection: make the job a required status check, with
branch protection on `main`, if a red result should stop a merge.

## Rules file

Rules live in `secret-scan.toml`: gitleaks' built-in ruleset, one extra rule
that matches AWS key IDs without needing a nearby keyword, and a short list of
allowlisted placeholder patterns.

The name is deliberate. gitleaks' built-in default config excludes every path
matching `gitleaks\.toml` from scanning, so a rules file under the usual
`.gitleaks.toml` name is the one file no scan can see.

There is a second trap: gitleaks exempts **the exact path it is handed as `-c`**
from scanning. Every scan here (both hooks, the `scan` task, CI) therefore
copies the rules file to a temporary path and passes that copy as the config,
so `secret-scan.toml` itself is scanned like any other file. Do not "simplify"
that to `-c secret-scan.toml`.

## Setup (once per checkout)

```bash
mise install            # installs the pinned gitleaks
mise run hooks:install  # git config core.hooksPath .githooks
```

`core.hooksPath` is per-clone, not per-repo, so the second command is the one
people forget. CI is the backstop when they do.

Manual scan of everything: `mise run scan`. A global `silent`/`quiet` setting in
`~/.config/mise/config.toml` hides the report — the exit status is still the
result, or prefix `MISE_QUIET=0 MISE_SILENT=0` to see what it found.

## Reading a finding

Local scans run with `-v`, so a block names the file, rule and commit. Be aware
of what `--redact` does and does not hide: it masks the matched value only, and
gitleaks still prints roughly 20 characters either side of it on that line. On a
one-line `.env` or JSON blob that can expose a neighbouring value, which is why
CI runs without `-v` — its output is kept in the Actions log, while a local
hook's output only reaches the person who already has the file.

If it fires:

1. **Rotate first.** Delete-then-commit leaves the value in history, and in
   every clone and CI log that already fetched it. Rotate in OpenBao.
2. Rewrite the offending commit (`git rebase -i`, or `git reset` if not pushed)
   so history never carried it.
3. If it was pushed: rotate, rewrite, force-push, and check whether a fork or
   CI artefact kept a copy.

## Placeholders

Documentation shows the shape of a value, never the value. Use
`__PASTE_ONCE__` or `<placeholder>` — both are allowlisted, so docs do not trip
the scanner. A real-looking example (a live-format key, even a dead one) is
indistinguishable from a leak and will be treated as one.

`gitleaks:allow` inline comments and `--no-verify` are for a reviewed false
positive only. A real block gets fixed, not waived.
