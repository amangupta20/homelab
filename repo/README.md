# Repo — how this repo itself works

Pages about the repository's own tooling, kept apart from the lab pages so you
do not wade through them when looking for something about the lab.

- `secret-scanning.md` — the scan that blocks a commit or push carrying a
  secret, a public IP, a tailnet name or your domain; setup per checkout.
- `obsidian-view.md` — the repo as an Obsidian vault: page properties, the
  tables in `bases/`, `Home.md`, and the check that keeps them valid.
- `review.md` — what a reviewer (AI subagent or person) checks before a
  change merges.
- What must pass before a change merges: `decisions/pull-request-gate.md`.
- How agents work here: `AGENTS.md` at the root.

Setup for a new checkout:

```bash
mise install            # pinned gitleaks, OpenTofu, tflint
mise run hooks:install  # point git at .githooks
cp secret-scan.local.toml.example secret-scan.local.toml   # then add your domains
```
