---
type: idea
status: "researched"
verified: "partially (releases, licences and archive status checked on the GitHub API 2026-11-15; the rest is research, not run here)"
tags:
  - idea
  - git
  - ci
---

# A self-hosted git host that mirrors to GitHub

**Status:** researched (2026-11-15). Five to try: OneDev, Forgejo, Harness Open
Source, GitLab CE and Tangled; nothing is scheduled.
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
on the list.

## Options and verdicts

"Git host" and "forge" mean the same thing here. Seventeen were surveyed. Scores
and features come from the research reports (Sources) unless marked as checked.

| Option | Looks (report score /10) | Mirror to GitHub | Verdict |
|---|---|---|---|
| **OneDev** | 9.5 | through a CI step, not a switch | **try**: the best for exploring code: jump-to-symbol in the browser and in review, code search, visual CI editor; mostly one maintainer. MIT; v17.2.0 on 2026-11-11 (checked) |
| **Harness Open Source** (was Gitness) | 9.0 | through a pipeline step; no built-in mirror per the reports | **try**: the slickest modern UI, Drone CI built in. It has no issue tracker (its issue #3373, "Issues", open since 2023, checked), which does not matter here. Apache-2.0 (checked) |
| **Forgejo** | 5 stock, about 8.5 themed | one switch, pushes on every change | **try**: the easiest mirror; CI runs GitHub Actions workflows nearly unchanged; imports GitHub pull requests. Plain until themed (Catppuccin has a maintained theme, checked) |
| **GitLab CE** | 6.5 | one switch | **try**: everything built in (CI, mirror, code navigation, web IDE); dense UI, the heaviest to run |
| **Tangled** | 8.5 | hook on the knot, or a GitHub Action | **try, differently**: see below |
| Gitea | 7.5 | one switch | same base as Forgejo, company-run; pick Forgejo over it unless Gitea's UI pulls clearly ahead. v28.3.0 on 2026-11-01 (checked) |
| Radicle | 8.0 | manual | **out as daily driver**: peer-to-peer, no built-in CI; interesting to run beside the main host |
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
- **Harness Open Source:** nothing gated in the self-hosted version (Apache-2.0).
  Harness's commercial platform is a separate product; the research says features
  such as SSO federation and governance stay there (unverified).
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

### Tangled works differently

Tangled splits a git host in two (tangled.org blog "intro", read 2026-11-15; the
split is also in the research reports):

- **Knot**: the server that stores repositories and serves git over SSH and HTTPS.
  This is what you self-host, on anything down to a Raspberry Pi. **Spindle** is
  its optional CI runner.
- **AppView**: the web UI. It runs on tangled.org and shows repositories from every
  knot. Running your own AppView is experimental per the reports.

So self-hosting Tangled means the code lives on our hardware and the UI lives at
tangled.org under the owner's Bluesky handle. There is no web UI to install, which
is likely why the owner found nothing when looking. It fails "our own instance
linked first", but it is a strong talking point and could run beside the main host.

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

- Run OneDev, Harness Open Source, Forgejo (themed) and GitLab CE side by side for
  a weekend, each with this repo imported and mirrored to a throwaway GitHub repo.
  Judge on exploring code, history and a pull request; keep the one the owner
  enjoys using. Put a Tangled knot beside them if the AT Protocol side appeals.
- The winner becomes the source of truth: push mirror to GitHub on every push;
  GitHub repo description and README point to the self-hosted copy.
- Public read-only browsing, sign-up off, owner signs in through the lab's
  identity provider.
- Mirrored commits still count on the GitHub contribution graph when the author
  email is one linked to the GitHub account and they land on the default branch
  (research report; GitHub's documented rule, not tested here).
- Port prime-reviewer as a CI job on the new host.

## Risks and costs

- Pull requests, issues and review history live only on our host. GitHub shows the
  commits, not the conversations.
- prime-reviewer is a GitHub App and has to be rewritten for the new host.
- Our host becomes the source of truth, so it needs the two-tier backups and a
  restore test (`skills/back-up-a-service/`) before it holds anything that matters.
- A public instance needs patching and sign-in kept up.
- OneDev depends mostly on one maintainer.

## Promote when

The owner has tried the candidates and picked one, and the home overhaul no
longer needs the attention.

## Sources

- Six research reports by Gemini workers, 2026-11-15 (landscape, Forgejo, newer
  UIs, mirroring and resume, community opinion, AI-era tools), kept in the owner's
  private notes. Their scores and feature claims are not verified here.
- Checked by an agent on 2026-11-15 with the GitHub API: OneDev v17.2.0, MIT;
  Gitea v28.3.0; Harness Apache-2.0 with issue #3373 ("Issues") open;
  charmbracelet/soft-serve archived; catppuccin/gitea maintained. HTTP 200 from
  gitriver.com, tangled.org, cursor.com/origin and the Anthropic post.
