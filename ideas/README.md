---
type: idea-index
tags:
  - ideas
  - index
---

# Ideas — researched, not scheduled

Designs worth trying once there is time or hardware for them. An idea has been
thought through far enough to know what it would take and what it would teach,
but nobody has committed to doing it. Nothing here describes the live lab.

How this folder relates to the others:

| Folder | Holds |
|---|---|
| `ideas/` | could do, someday; nothing is promised |
| `plans/` | will do, in this order, with gates |
| `systems/`, `inventory/` | is true now |
| `decisions/` | why it is the way it is |

**Promoting an idea:** when the owner decides to do it, write `plans/<what>.md`,
set the idea's Status to `promoted to plans/<what>.md` and keep the page — it
holds the research behind the plan. An idea that is ruled out stays too, with
Status `dropped` and the reason, so the next agent does not research it again.

**Who edits:** the owner adds ideas or asks an agent to write one up. Agents may
correct facts on a page and add sources; they never promote or drop an idea on
their own, and never start work from this folder.

Every page starts with a property block (the Obsidian view reads it); the
schema is in `repo/obsidian-view.md`, and `mise run check:properties` checks it.

Naming: `ideas/<what>.md`, lowercase with hyphens (`multi-site-postgres.md`).

## Template

```markdown
---
type: idea
status: "<idea | researched | promoted to plans/<x>.md | dropped>"
verified: "no (research only)"
tags:
  - idea
---

# <What>

**Status:** idea | researched | promoted to `plans/<x>.md` | dropped (<why>)
**In one line:** <what it is, for someone who has never heard of it>
**Why try it:** <what it would give the lab, or what it would teach>
**Needs first:** <hardware, money, or a plan that has to finish before this can start>

## Design sketch

## Risks and costs

## Promote when
<The condition that would turn this into a plan.>

## Sources
<Where the research came from: docs, a conversation, a test. Say what is unverified.>
```

## Ideas

- `multi-site-postgres.md` — a read-only copy of the database on the VPS that can take over if home is lost, with reads served locally at each site.
- `on-demand-container-wakeups.md` — give rarely-used stacks a live URL that starts them on first request and stops them when idle, so dozens of niche services cost nothing while forgotten. Needs more research: the reverse-proxy choice (NPM, Caddy, Traefik, Proxy-Wasm proxies) and the multi-host path are unresolved.
- `dsh-superagent-and-harness2.md` — a repo agent that takes work only when the owner asks and has its setup tuned automatically from past jobs; the candidate for the migration agent once the home agent VM exists.
- `edge-and-security-layers.md` — how public traffic reaches the lab and which security tool sits at which layer (Cloudflare, edge proxy and WAF, CrowdSec, sign-in, DNS, segmentation, detection, penetration testing). On hold until the Pangolin decision.
- `phone-control-panel.md` — an old Android phone running postmarketOS as a small dashboard at home, with an easy way to shut the server down. Barely explored.
- `iac-management-ui.md` — a self-hosted web UI to see, and possibly run, OpenTofu and Ansible, with the tools compared and what would make it worth adding.
- `try-netbird.md` — try NetBird, a self-hostable mesh VPN with its own UI and relay, on the side of Tailscale, with what it would cost and when to migrate.
- `llm-checked-updates.md` — every 3 days, an LLM reads available updates; clearly safe ones install, anything else waits for the owner, and every run is logged.
