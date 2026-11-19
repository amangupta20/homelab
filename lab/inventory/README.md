---
type: inventory-index
tags:
  - inventory
  - index
---

# Inventory — what exists

Lookup tables you can scan in seconds. One row per thing; the row says what it
is, where it runs, and its state. How a thing works belongs on its page in
`lab/systems/`, and the row links there once that page exists.

Every page starts with a property block (the Obsidian view reads it); the
schema and rules are in `agents/obsidian/obsidian-view.md`, and `mise run check:properties`
checks it.

| File | One row per | Owns |
|---|---|---|
| `services.md` | service or app | the service list |
| `hosts.md` | machine: bare metal, VM, VPS | the host list |
| `network.md` | IP address | every IP and how traffic flows in |

## Rules

- Tables, not prose. If a row needs a paragraph, the paragraph goes in
  `lab/systems/`.
- Each fact appears once. An IP is written in `network.md` only; other tables
  name the host.
- Every table says at the top that its rows are from the docs and not
  verified. A row checked against the live lab names the how in its State
  column (`verified: SSH`); the date goes in the page's "When each check ran"
  list, never in a cell (`mise run check:docs` fails on a dated cell).
- Unknown is written as `unknown`, never guessed.
- Only private addresses and placeholders. The scan blocks public IPs and
  tailnet names (`agents/review/secret-scanning.md`).
