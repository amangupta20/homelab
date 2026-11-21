# 2026-11-21 — Second Hermes WebUI updated to 0.52.723 with agent v0.23.1

**Who:** Claude Code (Opus 5.5)  **Scope:** `apps/vps/hermes-webui/` on the VPS (Dokploy)  **Mode:** write
**Task:** owner, in session: set up updating for this instance, update it once, write a skill  **Skill:** none (this
task wrote `agents/skills/update-hermes-webui/`)

## What changed

- Image `ghcr.io/nesquena/hermes-webui` 0.52.561 → 0.52.723 (newest stable release, published 2026-11-21).
- Agent v0.22.5 → v0.23.1, now copied into the home volume by the new one-shot `agent-src` service instead of by hand
  (`apps/vps/hermes-webui/NOTES.md`, "Choices"). v0.23.2 and v0.23.3 were skipped: NousResearch/hermes-agent#157091
  (tool turns fail on a custom chat-completions provider with encrypted reasoning; this instance uses a custom provider
  with `reasoning_effort: high`) and nesquena/hermes-webui#9213 (v0.23.3 cannot delete sessions), read on GitHub.
- Dokploy (API): branch set to `hermes-webui-update` for the deploy, and `autoDeploy` set to false (it was true; the
  docs said off — `agents/decisions/open-questions.md`, "Docs that disagree").

## Snapshot / backup taken

Container stopped, then both volumes streamed as tars to the owner's workstation
(`~/backups/hermes-webui-1-pre-update-2026-11-21/`), leaving out `hermes-agent/` (rebuilt from the agent image). Entry
counts equal the volumes' file counts (`find | wc -l` on the VPS: home 718, workspace 260); `tar -t` read each archive
to the end. Not restored.

## How it was verified

- `agent-src` exited 0 and logged `agent copied` with `displayVersion` 0.23.1; no `hermes-agent.new` left behind.
- WebUI log: override dependencies applied, 103 packages resolved, `Hermes agent critical imports verified`, agent dir
  `[ok]`, listening on 8787; container healthy, `RestartCount` 0.
- `hermes --version` in the container: `Hermes Agent v0.23.1`. `state.db` still holds 31 sessions.
- `/api/auth/status`: `auth_enabled`, `oidc_enabled` and `password_auth_enabled` all true. From outside, the page
  answers 302 to `/login` and `/api/sessions` 401 (`curl`).

## Still open

- A chat turn with a tool call after the upgrade, by the owner or the instance's user. UNTESTED until then.
- After the pull request merges: set the Dokploy service's branch back to `main` (no redeploy needed).
- The stack's real backups are still not set up (`apps/vps/hermes-webui/README.md`).
- Follow-up 2026-11-21: the owner checked a chat turn with a tool call after the upgrade, and it works. Dokploy is back on `main`.
