# 2026-11-22 — Free web search for every harness on agent-1

**Who:** Claude Code (Opus 5.5)  **Scope:** `agent-1`  **Mode:** write
**Task:** owner, in session: web search on every harness that needs it, with free providers that rotate
**Skill:** none

## What changed

- Hermes: `hermes plugins disable web-openai-native`. Hermes picked OpenAI's server-side search because a
  Codex sign-in exists (for image generation), and it cannot run with the opencode-go model, so every search
  failed and was rescued one call at a time. With it off, Hermes uses its keyless ring (Exa, Parallel,
  Firecrawl, Keenable, round-robin). Not in Ansible: it is Hermes's own state.
- `ansible/agent.yml`: pi gets `pi-web-access` (as on the owner's workstation; no key, Exa's free MCP endpoint
  first), and OpenCode 2 gets `files/agent/opencode.json`: `websearch.provider: random` (one free provider
  until it is rate limited, then another) and an allow rule for `websearch`, so unattended runs can search.
- Claude Code, Codex, omp and agy keep their own search tools; nothing changed for them.

## Snapshot / backup taken

None: configuration in the owner's home folder only.

## How it was verified

One query, "the current Debian 13 point release", in each harness's one-shot mode:
- Hermes: Exa, then Parallel, served keyless (`agent.log`); `web_extract` read debian.org/News (13.8).
- pi: 13.8 via Exa. OpenCode 2: 13.8, "Web Search via Parallel"; before the allow rule it was refused.
- Codex 13.8, agy 13.8; omp and Claude Code searched but answered 13.7 from a stale index.
- agy, after the owner's sign-in: "authenticated via keyring" in its log, so the unencrypted keyring works.
- `agent.yml`: a run (2 changed), then a second run with 0 changed.

## Still open

Whether Orca's OpenCode 2 workers read `~/.config/opencode` (Orca signs them in with private XDG folders).
