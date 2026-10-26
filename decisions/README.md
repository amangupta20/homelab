# Decisions

One file per decision: what was chosen, why, what it costs, and when. Facts
(what runs, which IP, which schedule) do not go here — they live in their owner
file and a decision links to it. A decision changes rarely; a fact changes
whenever the lab does. Keeping them apart means updating a fact never means
rewriting the reasoning behind it.

Anything not decided yet, or written down but never checked against the live
lab, goes in `open-questions.md` instead.

## Format

```markdown
# <the decision, as a sentence>

Decided: YYYY-MM-DD. Status: in force | superseded by <file>.

## Why
## Cost / what this rules out
## Where it lives  (links to the owner files that implement it)
```

When a choice gets a file here: when it rules out something an agent would
otherwise try to "fix" or re-open, and its reason does not fit in one line.
Keeping the VPS outside OpenTofu passes (an agent reading "reproducible from
code" would try to import it); choosing Raft storage for OpenBao does not, so
it is a sentence with its reason on `systems/openbao.md`.

Who edits: the owner of the lab decides. An agent may propose a new decision or
a change in a separate commit, but does not rewrite an existing one on its own.

## Index

- `agent-access.md` — convenient access for agents; disaster recovery is the safety net.
- `foundations-on-vps.md` — OpenBao and SSO on the VPS, over Tailscale.
- `vps-role.md` — what runs on the VPS instead of at home.
- `docs-layout.md` — facts in owner files, reasons here, no spec graph.
- `pull-request-gate.md` — what has to pass before a change merges.
- `remote-vps-in-scope.md` — the Dokploy VPS belongs here and will be migrated in.
- `vps-outside-opentofu.md` — the VPS itself is not managed by OpenTofu.
