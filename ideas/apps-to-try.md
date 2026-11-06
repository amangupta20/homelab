---
type: idea
status: "idea"
verified: "no (one-line notes from each project's README)"
tags:
  - idea
  - backlog
---

# Apps to try

**Status:** idea (backlog list). These are apps the owner might self-host one day. Nothing here is researched or scheduled.
**In one line:** a backlog of apps the owner found and wants to try, one line each.
**Why try it:** so a find doesn't get lost in browser tabs, and so agents can see what the owner is thinking of hosting (it matters for ideas like [on-demand container wakeups](on-demand-container-wakeups.md)).
**Needs first:** the migration finishes before anything here starts, unless the owner says otherwise.

## How an entry moves

1. **Listed here:** the owner saw it and thinks it looks interesting. One row, no research.
2. **Its own page, `ideas/<app>.md`:** someone has looked into it (resources, sign-in, backups, overlap with what already runs). The row links to that page.
3. **Deployed:** a plan or a straight deploy (`skills/deploy-on-dokploy/`), then the service goes in `inventory/services.md`. Remove the row, or leave it with a link to the service.

An app that gets ruled out keeps its row, with the reason in "Waits on / notes", so nobody looks into it again.

## List

"What it is" comes from each project's README (read 2026-11-02 with a web fetch), not from running it.

| App | What it is | Waits on / notes |
|---|---|---|
| [Karakeep](https://github.com/karakeep-app/karakeep) (formerly Hoarder) | Bookmark-everything app for links, notes and images, with AI tagging and full-text search. Runs on Docker; the README lists Meilisearch for search and OpenAI or local Ollama models for tagging. | migration |
| [Blinko](https://github.com/blinkospace/blinko) | Self-hosted AI note-taking app focused on privacy. Runs on Docker; "postgres" is one of its repo tags, but the README doesn't say what database it needs. | migration |
| [Floci](https://github.com/floci-io/floci) | Local AWS emulator for development, testing and CI: no account or auth token, and it presents itself as a drop-in replacement for LocalStack. Has an arm64 image. | later; owner, 2026-11-06 |
| [DashBeam](https://github.com/tonyantony300/dashbeam) | Peer-to-peer encrypted file transfer between devices (desktop, Android, CLI, browser), with no cloud storage and no accounts. Its relay and discovery servers are the only parts you can self-host (documented in the repo's `infra` folder). | migration; check whether a self-hosted relay is worth running |

## Sources

- The project READMEs linked in the table, read 2026-11-02 (Floci's 2026-11-06, with `docker buildx imagetools inspect`). Unverified: none of these apps has been run in the lab.
