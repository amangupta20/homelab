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
| [Remux](https://github.com/lostb1t/remux) | Media server written in Rust that speaks the Jellyfin API, so Jellyfin apps connect unchanged. Sources are Stremio add-ons, WebDAV shares (TorBox has one) and torrents, streamed on demand with nothing stored; libraries are built from filters and can be scoped per user. AGPL-3.0; v0.40.0 on 2026-11-07, nightly builds daily. Its issues show ffmpeg transcoding with Intel Quick Sync and HLS output. | the GPU VM (`plans/home-overhaul.md`). Best fit found for streaming from TorBox (agent research, 2026-11-14), not tried: per-library and per-user access, no mount. Trickplay and the temporary-cache size not checked |
| [Rex](https://github.com/debridmediamanager/rex) | From the Debrid Media Manager authors: a server written in Rust that Plex apps take for a Plex Media Server, filled from debrid accounts (through zurg) and Stremio add-ons. GPU transcoding through Plex's transcoder settings; chapter and seek-bar thumbnails from its own analysis, manual by default; per-share library and rating filters. Created 2026-09, nightly builds; licence not stated. | candidate for streaming from TorBox, the only one found with seek-bar thumbnails. Must be claimed with a plex.tv account ("Plex could act against the account that claims it", README); its Android app is for sponsors only |
| [Polyfin](https://github.com/moodiness/polyfin) | Speaks the Jellyfin API: Stremio add-ons, IPTV and folders become libraries any Jellyfin app plays; per-user visible libraries, limits and parental control; GPU transcoding on NVIDIA, AMD or Intel with HDR tone mapping. MIT; created 2026-10, v0.76.0 on 2026-11-12. | candidate for streaming from TorBox (through add-ons); seek-bar thumbnails not confirmed; six weeks old |
| [Ether](https://github.com/braedonsaunders/ether) | One server for Plex, Jellyfin, Emby, Infuse and Stremio apps at once; streams from TorBox and other debrid services or Usenet directly, no mount. Shows the whole TMDB catalogue by design. GPL-3.0; created 2026-10, v0.3.10. | weak fit: built to show everything, the opposite of a curated library; four weeks old |
| [Gelato](https://github.com/lostb1t/Gelato) | Jellyfin plugin that puts Stremio add-on results (through AIOStreams only) into a Jellyfin library. | ruled out: tried before, the owner did not like it (2026-11-14) |
| [TorBox Media Center](https://github.com/TorBox-App/torbox-media-center) | TorBox's own tool: the whole TorBox account as `.strm` files or a FUSE mount. | ruled out: it exposes the whole account in one place, and the owner wants separate libraries with per-user access (2026-11-14) |
| [Decypharr](https://github.com/sirrobot01/decypharr) | Stands in for qBittorrent towards Sonarr/Radarr, adds items to a debrid account and serves them through a mount with a local cache; Jellyfin reads symlinks into the mount. | fallback to Remux: the only researched route that keeps Jellyfin's trickplay, by reading whole files through the cache. Can also feed Remux instead of Jellyfin: Remux reads WebDAV shares and local folders, so Sonarr/Radarr and Decypharr pick what appears and Remux serves it (owner's idea, 2026-11-14; untested whether Decypharr's WebDAV shows only its own items) |

## Sources

- The project READMEs linked in the table, read 2026-11-02 (Floci's 2026-11-06, with `docker buildx imagetools inspect`). The streaming rows were read 2026-11-14: Remux's README, release list and issue titles through GitHub's API, the others from web search and four agent research reports kept outside this repo. Unverified: none of these apps has been run in the lab.
