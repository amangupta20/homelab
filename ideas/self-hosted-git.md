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

**Status:** researched (2026-11-15). Two finalists, OneDev and Forgejo, to be tried
side by side; nothing is scheduled.
**In one line:** run our own git host (repositories, pull requests, issues, CI) as
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

1. **Looks first.** A modern, polished UI that is fun to use matters more than
   resource use; bloat is fine. The owner does not like GitLab's UI.
2. Works as a daily driver: repositories, pull requests with a good review UI, CI,
   issues.
3. Pushes everything to GitHub automatically; GitHub stays the public face.
4. Fun to run.

## Options and verdicts

"Git host" and "forge" mean the same thing here. Seventeen were surveyed. Scores
and features come from the research reports (Sources) unless marked as checked.

| Option | Looks (report score /10) | Mirror to GitHub | Verdict |
|---|---|---|---|
| **OneDev** | 9.5 | through a CI step, not a switch | **finalist**: richest UI, jump-to-symbol in code and review, boards, visual CI editor; mostly one maintainer. MIT; v17.2.0 on 2026-11-11 (checked) |
| **Forgejo** | 5 stock, about 8.5 themed | one switch, pushes on every change | **finalist**: imports GitHub repos, issues and pull requests; CI runs GitHub Actions workflows nearly unchanged; non-profit governance. Plain until themed (Catppuccin has a maintained theme, checked) |
| Gitea | 7.5 | one switch | same base as Forgejo, company-run; pick Forgejo over it unless Gitea's UI pulls clearly ahead. v28.3.0 on 2026-11-01 (checked) |
| Harness Open Source (was Gitness) | 9.0 | no built-in mirror per the reports | **out**: the slickest UI, but it has no issue tracker (its issue #3373, "Issues", open since 2023, checked) |
| Tangled | 8.5 | manual (hook or Action) | **wildcard**: a git host on Bluesky's AT Protocol; a strong resume talking point, young project |
| Radicle | 8.0 | manual | **out as daily driver**: peer-to-peer, no built-in CI; interesting to run beside the main host |
| GitRiver | 8.5 | unverified | **unknown**: a 2026 newcomer, open-core licence; site exists (checked), nothing else verified |
| GitLab CE | 6.5 | one switch | **out**: the owner dislikes its UI |
| Phorge, RhodeCode, Pagure, Kallithea, GitBucket, Gogs | 4–5.5 | mixed | **out**: dated UIs, or in maintenance mode |
| Sourcehut | by design minimal | manual | **out**: email-driven, no-JavaScript by design |
| Soft Serve | terminal only | manual | **out**: archived (checked) |

The field is genuinely small. Most self-hostable git hosts are either Gitea-family,
older projects with dated UIs, or experiments; only OneDev and Forgejo are both
pleasant and complete for daily use today.

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

- Run OneDev and Forgejo side by side for a weekend, each with one real repo
  (this one) mirrored to a throwaway GitHub repo, and keep the one the owner
  enjoys using.
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

The owner has tried both finalists and picked one, and the home overhaul no
longer needs the attention.

## Sources

- Six research reports by Gemini workers, 2026-11-15 (landscape, Forgejo, newer
  UIs, mirroring and resume, community opinion, AI-era tools), kept in the owner's
  private notes. Their scores and feature claims are not verified here.
- Checked by an agent on 2026-11-15 with the GitHub API: OneDev v17.2.0, MIT;
  Gitea v28.3.0; Harness Apache-2.0 with issue #3373 ("Issues") open;
  charmbracelet/soft-serve archived; catppuccin/gitea maintained. HTTP 200 from
  gitriver.com, tangled.org, cursor.com/origin and the Anthropic post.
