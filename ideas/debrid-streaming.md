---
type: idea
status: "researched"
verified: "partially (each candidate's repository read 2026-11-14; the rest is research, not run here)"
tags:
  - idea
  - media
  - debrid
  - streaming
---

# Streaming from TorBox through our own server

**Status:** researched (2026-11-14); a hands-on comparison is a later step of
`plans/home-overhaul.md`, after the GPU cutover.
**In one line:** play films and series from the owner's TorBox debrid account through a
self-hosted media server that transcodes on the GPU, instead of keeping the files on
disk.
**Why try it:** Jellyfin today needs every file on local disk (`Main/home/media`), which
costs space; Stremio stores nothing but plays on the phone, which brings codec and
compatibility problems and no server-side transcoding.
**Needs first:** `gpu-1` (`plans/home-overhaul.md`).

## What the owner wants (2026-11-14)

1. No permanent media storage: fetched from TorBox when needed, at most a bounded
   temporary cache (20–50 GB).
2. The server transcodes for phones on the GPU, so clients never hit codec, HDR, audio
   or subtitle problems.
3. Separate libraries (films, series, anime, children's) with per-user access.
4. Real media-server features: metadata, watch history, resume across devices, several
   users, ideally seek-bar thumbnails (trickplay).
5. Only what the owner adds or requests appears — never the whole TorBox account.

## Options and verdicts

Checked against each project's repository on 2026-11-14 (GitHub API: creation date,
latest release, licence; README). Behaviour is from their docs, not from running them.

| Option | How it works | Verdict |
|---|---|---|
| [Remux](https://github.com/lostb1t/remux) | A server that speaks the Jellyfin API; sources are Stremio add-ons, WebDAV shares (TorBox has one) and torrents, streamed on demand. Libraries built from filters and scoped per user. AGPL-3.0, created 2026-02, v0.40.0 on 2026-11-07. Its issues show ffmpeg transcoding with Intel Quick Sync and HLS. | candidate. Gelato's author made it and Gelato's README points to it. No trickplay; one maintainer |
| [Rex](https://github.com/debridmediamanager/rex) | From the Debrid Media Manager authors; Plex apps take it for a Plex server. Sources: debrid accounts through zurg, Stremio add-ons. Chapter and seek thumbnails from its own analysis (manual by default); per-share library filters. Created 2026-09, licence not stated. | candidate, the only one with seek thumbnails. Must be claimed with a plex.tv account, and its README warns Plex could act against that account |
| [Polyfin](https://github.com/moodiness/polyfin) | Speaks the Jellyfin API; add-ons and folders become libraries; per-user visible libraries, limits and parental control; GPU transcoding with HDR tone mapping. MIT, created 2026-10, v0.76.0 on 2026-11-12. | candidate to watch; seek thumbnails not confirmed; young |
| [Decypharr](https://github.com/sirrobot01/decypharr) + Jellyfin | Sonarr/Radarr send releases to Decypharr, which adds them to TorBox and makes symlinks; Jellyfin reads them through a mount with a local cache. MIT, since 2024-08, v2.7.2 on 2026-11-02; lists TorBox. | fallback: the most proven, Jellyfin's full transcoding, Jellyfin's own per-user libraries; many moving parts |
| Decypharr + Remux | Sonarr/Radarr and Decypharr choose what appears; Remux serves it through its WebDAV or local-folder sources. | the owner's idea; untested whether Decypharr's WebDAV shows only its own items |
| [Ether](https://github.com/braedonsaunders/ether) | One server for Plex, Jellyfin, Emby, Infuse and Stremio apps; TorBox direct. GPL-3.0, created 2026-10. | weak fit: built to show the whole TMDB catalogue |
| [Gelato](https://github.com/lostb1t/Gelato) | Jellyfin plugin that puts Stremio add-on results into a library, through AIOStreams. | ruled out: the owner tried it and did not like it |
| [TorBox Media Center](https://github.com/TorBox-App/torbox-media-center) | TorBox's own tool: the whole account as `.strm` files or a mount. | ruled out: one place for the whole account, no split by library or user |
| Stremio alone | The phone resolves and plays streams itself. | ruled out: no server-side transcoding |

## Trade-offs worked out

- **A capped cache with a mount.** rclone's `--vfs-cache-mode full` with
  `--vfs-cache-max-size` evicts the least recently used pieces, so generating Jellyfin's
  trickplay for 100 GB of episodes with a 50 GB cap ends with about 50 GB cached and the
  thumbnails kept in Jellyfin's own metadata folder. The cost: every file is downloaded
  once, the GPU decodes all of it, the cache churns, and it can briefly go over the cap
  while files are open. Run such tasks at night with low parallelism.
- **TorBox's limits** (reported by users and agent research, not confirmed in TorBox's
  own documentation here): about 300 API requests a minute and 60 uncached torrents an
  hour; abuse detection since May 2026 that watches files kept "active". Media servers'
  library scans can hit the request limit, which is why stable setups put a caching
  proxy such as [Warpbox](https://github.com/mainlink0435/warpbox) or a purpose-built
  server between the scan and TorBox. Full trickplay passes over a large library are
  the riskiest pattern.
- **Seek thumbnails:** every option without a mount loses them except Rex; with a mount
  they cost a full read of each file.

## The old arr stack

Stopped for about 14 months on `gpu_docker`: Sonarr, Radarr, Prowlarr, Lidarr, Readarr,
Bazarr, qBittorrent behind gluetun, NZBGet, pyLoad, Jellyseerr, a FlareSolverr
replacement and tdarr, with configs under `/docker/<app>` and media in
`Main/home/media` (SSH and Portainer API, 2026-11-14). It is a clean-up candidate
(`plans/home-overhaul.md`, B1); the Decypharr route would bring Sonarr, Radarr and
Prowlarr back.

## Sources

The repositories linked above, read 2026-11-14. Seven agent research reports from the
same day are kept outside this repo; only the facts checked against primary sources
are on this page.
