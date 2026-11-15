---
type: idea
status: "researched"
verified: "partially (releases, licences, archive status and image tags checked via APIs 2026-11-15; OneDev, Forgejo and Harness tried locally in Docker on the owner's laptop; the rest is research, not run here)"
tags:
  - idea
  - git
  - ci
---

# A self-hosted git host that mirrors to GitHub

**Status:** researched (2026-11-15). Two tracks, decided by the owner the same
day: **Forgejo and OneDev** are the full main-host candidates; **Tangled and
Radicle** are exploration beside whichever wins. GitLab CE and Harness Open
Source dropped. Nothing is scheduled.
**In one line:** run our own git host (repositories, pull requests, CI) as
the daily driver, and have it push every change to GitHub, so the public and
recruiters still see everything there.
**Why try it:** GitHub's web UI has become slow and unreliable to work in. On
2026-11-15 a pull request stayed stuck on "Merge already in progress" after a
bypass merge, and the `main` ruleset demands an approval that nobody can give on a
solo repo. A host of our own removes both, and is itself something to show: the
owner wants their own instance linked first on a resume for homelab work, with
GitHub second.
**Needs first:** nothing hard; it fits on Dokploy or a small VM. Better after
`plans/home-overhaul.md`, so it does not stack a new platform on a migration.

## What the owner wants (2026-11-15)

1. **A nice-looking UI to explore everything in**: browsing code, history,
   branches, pull requests and CI runs. This is the main requirement; resource use
   and bloat do not matter.
2. Pull requests with a good review UI, and CI hooks (webhooks or a pipeline) so
   prime-reviewer and the checks can run. A complicated setup is fine.
3. **No issue tracker needed**: the lab does not use issues.
4. Pushes everything to GitHub; GitHub stays the public face. Mirroring through a
   CI step or hook is acceptable.
5. Fun to run.

The owner first ruled GitLab out on its UI, then (same day) asked for it to stay
on the list, then dropped it after the comparison (memory it would take beside
the agent VM).

## Options and verdicts

"Git host" and "forge" mean the same thing here. Seventeen were surveyed. Scores
and features come from the research reports (Sources) unless marked as checked.

| Option | Looks (report score /10) | Mirror to GitHub | Verdict |
|---|---|---|---|
| **OneDev** | 9.5 | through a CI step, not a switch | **main candidate**: the best for exploring code: jump-to-symbol in the browser and in review, code search, visual CI editor; mostly one maintainer. MIT; v17.2.0 on 2026-11-11 (checked) |
| Harness Open Source (was Gitness) | 9.0 | through a pipeline step; no built-in mirror per the reports | **dropped** (owner, 2026-11-15): the slickest UI, but no stable release since August 2025 and its new UI sends secrets, connectors and ten more settings pages to an Enterprise upsell (see below) |
| **Forgejo** | 5 stock, about 8.5 themed | one switch, pushes on every change | **main candidate**: the easiest mirror; CI runs GitHub Actions workflows nearly unchanged; imports GitHub pull requests. Plain until themed (Catppuccin has a maintained theme, checked) |
| GitLab CE | 6.5 | one switch | **dropped** (owner, 2026-11-15): everything built in, but 8–16 GB of memory leaves too little for `agent-1` and `gpu-1` |
| **Tangled** | 8.5 | hook on the knot, or a GitHub Action | **exploration**: a knot and spindle beside the main host; see below |
| Gitea | 7.5 | one switch | same base as Forgejo, company-run; pick Forgejo over it unless Gitea's UI pulls clearly ahead. v28.3.0 on 2026-11-01 (checked) |
| **Radicle** | 8.0 | manual (add GitHub as a remote) | **exploration**: peer-to-peer, issues and patches stored in git; seed nodes at home and on the VPS; see below |
| GitRiver | 8.5 | unverified | **unknown**: a 2026 newcomer, open-core licence; site exists (checked), nothing else verified |
| Phorge, RhodeCode, Pagure, Kallithea, GitBucket, Gogs | 4–5.5 | mixed | **out**: dated UIs, or in maintenance mode |
| Sourcehut | by design minimal | manual | **out**: email-driven, no-JavaScript by design |
| Soft Serve | terminal only | manual | **out**: archived (checked) |

The field is genuinely small. Most self-hostable git hosts are either Gitea-family,
older projects with dated UIs, or experiments.

### What each one keeps behind a paywall

Read from each vendor's pricing or docs page on 2026-11-15, except where marked.

- **Forgejo:** nothing. No paid edition; run by a non-profit (Codeberg e.V.).
- **Tangled:** nothing found; no pricing page on tangled.org. Its web UI is a
  service it runs, so the terms could change.
- **Harness Open Source:** Apache-2.0, but the `unstable-uiv2` build's settings
  menu shows Harness Platform pages that open an "Upgrade to Harness Enterprise"
  screen (owner spotted it; an agent then opened each page, 2026-11-15 local trial):
  notifications, environments, connectors, delegates, secrets, file store,
  templates, variables, policies, freeze windows, certificates and overrides.
  Repositories, pipelines, pull requests, users, roles and webhooks opened. The
  stable 3.3.0 web UI was not checked.
- **OneDev:** a free Community Edition, and an Enterprise Edition at $6 per user
  per month (minimum 12 user-months per order). Paid: code search across all
  projects (search within one project is free), custom dashboards, statistics and
  trends, a web terminal into running CI jobs, security and licence scanning, audit
  log, time tracking, Renovate integration, clustering. Free includes symbol
  navigation, the visual CI editor, the package registry, SSO and the AI users.
- **GitLab CE (Free tier):** push mirroring, merge request review and auto-merge
  are free. Paid (Premium and up): approval rules, code owners, merge trains, pull
  mirroring and advanced code search across projects (GitLab docs, each page's
  "Tier" line). The AI features (Duo) are mostly paid.
- **Gitea (for comparison):** Gitea Enterprise sells branch protection inherited
  from the organisation, dependency scanning, IP allowlists, SAML, audit log, and
  "Enterprise themes". Forgejo has no equivalent paid tier.

For a solo owner who wants to explore code in a good-looking UI, the only paywall
that touches the goal is OneDev's cross-project code search and dashboards, at $6
a month for one user.

### Harness Open Source: what the web UI has, and its release problem

What it includes, from its README and the research reports: repositories and pull
requests (with code owners, tag rules and a pull request dashboard in 3.3.0),
pipelines (the successor to Drone CI), **Gitspaces** (one-click development
environments from a `.devcontainer`, opened in VS Code in the browser) and an
artifact registry that can proxy upstream registries. A React web app with dark
mode; the reports rate it the most modern-looking self-hosted UI. No issues.

Checked on the GitHub API and Docker Hub (2026-11-15):

- **The last stable release is 3.3.0, from 2025-08-19**, and the `latest` Docker
  image still points to it. The 2026 releases numbered v2.27–v2.28 are built from
  the `drone` branch: they are Drone, not Harness Open Source.
- `main` is busy (commits daily in November 2026), but ships only as `unstable`
  and `unstable-uiv2` images, both updated 2026-11-12. `uiv2` suggests a new web
  UI is coming (a guess from the tag name).
- Commit titles carry the ticket prefixes of Harness's commercial products
  (`CODE-`, `AICR-`), so the open-source build looks like a by-product of the paid
  platform rather than its own release line (an inference).

Trying it means either a stable build fifteen months old or an `unstable` one.

### Tried locally, and the fit with the agent VM (2026-11-15)

OneDev 17.2.0, Forgejo 17 and Harness `unstable-uiv2` were run in Docker on the
owner's laptop with this repo and pull request #79 imported. Seen:

- **Forgejo** read `.github/workflows` unchanged and listed every workflow as a
  pending check on the pull request (no runner was attached). 73 MB at idle.
- **Harness** turned the same workflows into its own pipelines on import. 76 MB at
  idle. On that build, opening a file by link showed "404 Not Found".
- **OneDev** has no reader for GitHub workflows. Its memory use follows the
  limit it is given: Java sizes its heap to half the memory it can see
  (`-XX:MaxRAMPercentage=50` in `conf/wrapper.conf`). Without a container limit
  it allowed itself an 8.2 GB heap and used 0.6–1.8 GB; capped at 1 GB (512 MB
  heap) it served the same pages using about 800 MB. Give it a limit of 1–1.5 GB.
- GitLab was not run; its install requirements page gives 16 GB as the single-node
  baseline and 8 GB as the minimum.

Idle memory from `docker stats` with two repositories each. The host has 40 GB
and the running VMs take about 22 (`plans/home-overhaul.md`), which rules GitLab
out beside `agent-1` and `gpu-1`. Forgejo fits the agent VM best: its runner on
`agent-1` would give every agent branch the CI and prime-reviewer it gets on
GitHub today. OneDev is the most agent-minded (AI users, a CLI that runs CI
against uncommitted changes) but needs its CI rewritten and a memory limit.

### Tangled works differently

Tangled splits a git host in two (tangled.org blog "intro", read 2026-11-15; the
split is also in the research reports):

- **Knot**: the server that stores repositories and serves git over SSH and HTTPS.
  This is what you self-host, on anything down to a Raspberry Pi. **Spindle** is
  its optional CI runner.
- **AppView**: the web UI. It runs on tangled.org and shows repositories from every
  knot. Running your own AppView is experimental per the reports.

So self-hosting Tangled today means the code lives on our hardware and the UI
lives at tangled.org under the owner's Bluesky handle.

Checked on Tangled's blog and docs (2026-11-15). Tangled hosts its own source on
tangled.org, not GitHub, which is why general web searches find little:

- Its 2026-10-30 post ("The federated code forge") says every part can be
  self-hosted, "including the API server and UI". The docs list five parts (knot,
  spindle, client, index, PDS), but the "Run a frontend" page says "Coming soon".
  So our own Tangled UI is announced, not yet documented.
- The company is Tangled Labs Oy; it announced a €3.8M seed round on 2026-03-02.
- 2026 additions: code search across the network, CI in QEMU microVMs, CI logs
  over SSH, a "vouching" web of trust against spam, and a read-only API
  (api.tangled.org).
- Moving from GitHub: an importer brings repos, emails and SSH keys; the docs
  have a section on pushing to both GitHub and Tangled.

It fails "our own instance linked first" until the self-hosted UI ships, but it
is a strong talking point and could run beside the main host.

### AI-era git hosts (2026)

Checked that the pages exist, not what they claim:

- **Cursor Origin** (cursor.com/origin): Cursor's own git host for parallel coding
  agents, with two-way GitHub sync. SaaS only.
- **Anthropic** wrote up an internal replacement for git built for agent-heavy work
  (anthropic.com/research/redesigning-source-control, 2026-10-13). Internal only.
- The reports also name an OpenAI tool and a Cursor purchase of Graphite;
  unverified.

None of these can be self-hosted. What can: OneDev's built-in AI features, or a
self-hosted review bot (PR-Agent, Kodus; unverified) on Forgejo, which could
replace prime-reviewer.

## Design sketch

Two tracks. The main host is the source of truth; the exploration track takes a
push from it and is never the only copy of anything.

### Track 1: the main host (Forgejo or OneDev)

Run both side by side for a weekend with this repo imported, judge on exploring
code, history and a pull request, and keep one. The local trial on 2026-11-15
(above) was the first look. Whichever wins:

- It is the source of truth and mirrors every push to GitHub (built-in push
  mirror on Forgejo; a CI step on OneDev). The GitHub repo description and README
  point back to it.
- Public repositories can be browsed without signing in; sign-up is off; the
  owner signs in through Authentik, as Langfuse already does (`inventory/services.md`).
- It runs as a container (Dokploy or `docker-1`); its CI runners run on
  `agent-1`, because a runner needs the Docker socket.
- Mirrored commits still count on the GitHub contribution graph when the author
  email is one linked to the GitHub account and they land on the default branch
  (research report; GitHub's documented rule, not tested here).

### A full Forgejo setup

What "everything switched on" would look like. Marked by how each part is known.

| Part | What it does | How known |
|---|---|---|
| Forgejo server | Container; Catppuccin themes, custom landing page in `custom/templates/home.tmpl`, code search with the built-in indexer | Tried locally 2026-11-15 |
| Database | Postgres on the shared cluster (`plans/shared-postgres.md`) instead of SQLite | Supported per Forgejo docs; not tried |
| Object storage | Attachments, LFS, packages, Actions logs and artifacts in Garage (S3); git repos stay on disk | Forgejo docs; not tried |
| Runners | `forgejo-runner` on `agent-1` running the existing `.github/workflows` | Registered and picked up the jobs locally; no job finished, because the job images would not download over the laptop's connection |
| Reviewers | prime-reviewer as a workflow, with its posting step ported from GitHub's API to Forgejo's; PR-Agent has a Gitea provider as a second reviewer | Forgejo looked for `prime-reviewer-action` on its own action mirror and hung, so the action must be referenced by full URL; PR-Agent's Gitea provider file exists (checked), untried with Forgejo |
| Dependency updates | Renovate, which lists Forgejo as a supported platform | Renovate docs page exists (checked); not tried |
| Mirrors | Push mirror to GitHub; second push mirror to a Tangled knot | Forgejo allows several push mirrors per repo (docs); not tried |
| Sign-in | Authentik over OpenID Connect; `ALLOW_ONLY_EXTERNAL_REGISTRATION=true`, `ENABLE_INTERNAL_SIGNIN=false`, `ENABLE_AUTO_REGISTRATION=true`, `REQUIRE_SIGNIN_VIEW=false`; an Authentik policy limits who can sign in | Setting names from Forgejo's config docs (checked); not tried |
| Agent access | `tea` CLI, access tokens kept in OpenBao, an MCP server (`goern/forgejo-mcp`, a mirror of a Codeberg project) | MCP repo exists (checked); not tried |
| Registry | Container and package registry, so CI can publish images | Forgejo docs; not tried |
| Monitoring | A metrics endpoint for Prometheus | From memory, unverified |
| Backups | `forgejo dump` or the data folder plus a Postgres dump, through `skills/back-up-a-service/`, with a restore test | Not tried |

Federation (ForgeFed) stays off: the research reports call it experimental.

**Reference build: Codeberg.** Codeberg.org runs Forgejo (its API reported
`17.0.0-100-2254cb0+gitea-1.22.0` on 2026-11-15, a little ahead of the 17.0
release), operated by Codeberg e.V., the non-profit that has backed Forgejo's
development since 2022 and avoids commercial or proprietary services in its
operation (docs.codeberg.org, "What is Codeberg?"). Its extras on top of Forgejo
are the model for ours: Codeberg Pages (static sites deployed from Forgejo
Actions), hosted CI, and documented self-hosted runners. When building the full
setup, read how Codeberg does a part before inventing our own. It also defends
hard against automated scraping: headless browser requests got placeholder pages
and rate-limit messages during this research.

### Track 2: exploration (Tangled and Radicle)

Both take pushes from the main host and are never the only copy.

- **Tangled:** a knot (repo storage) and spindle (CI) in the lab, registered to
  the owner's Bluesky handle; the main host pushes to the knot as a second mirror.
  The web UI is tangled.org until Tangled ships its self-hosted one. The
  spindle's microVM engine needs `/dev/kvm`, so it wants a VM with nested
  virtualisation or bare metal (untested on XCP-ng).
- **Radicle** (1.10.3, 2026-09-08, read on radicle.xyz): peer-to-peer; issues
  and patches are signed objects stored in git, so there is no database. Seed
  nodes at home and on the VPS replicate each other, which makes it the natural
  two-site experiment. Web view, terminal UI, CLI and a desktop app; CI through a
  separate broker; Linux, macOS and BSD only.

### Later, for fun: two sites

Git branches can sync both ways between home and the VPS (a hook pushes each
updated branch to the other site, fast-forward only, so a branch moved on both
sides is refused and flagged). Forgejo's own push and pull mirrors cannot do
this: a push mirror deletes branches that only exist on the other side, and a
pull mirror makes the repo read-only. Pull requests and comments live in the
database, so they stay single-primary: both Forgejo instances use the one
Postgres primary at home, with a replica on the VPS (`ideas/multi-site-postgres.md`).
Radicle gets two-site sync without any of this.

## Risks and costs

- Pull requests, issues and review history live only on our host. GitHub shows the
  commits, not the conversations.
- prime-reviewer is a GitHub App and has to be rewritten for the new host.
- Our host becomes the source of truth, so it needs the two-tier backups and a
  restore test (`skills/back-up-a-service/`) before it holds anything that matters.
- A public instance needs patching and sign-in kept up.
- OneDev depends mostly on one maintainer.

## Promote when

The owner has tried Forgejo and OneDev side by side and picked one, `agent-1`
exists for the runners, and the home overhaul no longer needs the attention. The
exploration track does not gate this.

## Sources

- Six research reports by Gemini workers, 2026-11-15 (landscape, Forgejo, newer
  UIs, mirroring and resume, community opinion, AI-era tools), kept in the owner's
  private notes. Their scores and feature claims are not verified here.
- Checked by an agent on 2026-11-15 with the GitHub API: OneDev v17.2.0, MIT;
  Gitea v28.3.0; Harness Apache-2.0 with issue #3373 ("Issues") open;
  charmbracelet/soft-serve archived; catppuccin/gitea maintained. HTTP 200 from
  gitriver.com, tangled.org, cursor.com/origin and the Anthropic post.
