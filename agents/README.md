# Agents — how every harness gets this repo's skills and rules

This repo is meant to be worked on by several agent harnesses — Claude Code,
Pi, omp, Codex, OpenCode, Hermes, and whatever gets tried next — on more than
one machine. None of them owns anything: the instructions (`AGENTS.md`) and the
skills (`skills/`) live in the repo, and each harness is pointed at them. Clone
the repo anywhere and the same skills and rules apply.

## How each harness finds the skills

| Harness | Reads skills from | How it gets there | Checked |
|---|---|---|---|
| Pi | `.agents/skills/` (project) | committed link to `skills/` | Pi 1.4.0 `docs/skills.md`, 2026-10-26 |
| omp | `.agents/skills/`, `.claude/skills/` (project) | committed links | paths in the omp binary, 2026-10-26; may list each skill twice |
| Claude Code | `.claude/skills/` (project) | committed link to `skills/` | Claude Code docs |
| Codex, OpenCode, Gemini / Antigravity | `.agents/skills/` (project) | committed link | not checked: the agentskills.io convention |
| Hermes | `~/.hermes/skills/` (home directory only) | `agents/link.sh` | third-party guides; confirm on the agent VM |

The project links work as soon as the repo is cloned. Harnesses that only read
a folder in your home directory are listed in `agents/harnesses.txt` and need
one command per machine:

```bash
mise run agents:link    # or: sh agents/link.sh
```

Pi asks you to trust a project before it loads project skills; that is
expected, not an error.

## How each harness finds the rules

`AGENTS.md` at the root. Harnesses that look for `CLAUDE.md` instead get a
one-line `CLAUDE.md` that points at it — one copy of the rules, never two.

## Adding a harness

1. If it reads `.agents/skills/` or `.claude/skills/` in the project: nothing
   to do. Add it to the table above with how you checked.
2. If it only reads a folder in your home directory: add a line to
   `agents/harnesses.txt` and run `mise run agents:link`. Use `adopt` if it
   writes skills on its own.
3. If it needs harness-specific code (an extension, a plugin): put it in
   `agents/extensions/<harness>/`.

## Not here

- Each harness's own memory, sessions and settings stay in its home directory
  and are not a source of truth. Facts an agent learns go into the repo.
- Credentials never: they come from OpenBao or the environment.
- Shared MCP server definitions: none yet. When the first one is added it gets
  one copy here (`agents/mcp/`), with a note on how each harness loads it.
