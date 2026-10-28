---
type: inventory-index
status: active
verified: "yes (index file)"
hosts: unknown
related:
  - "[Services](services.md)"
  - "[Hosts](hosts.md)"
  - "[Network](network.md)"
tags:
  - inventory
  - index
---

# Inventory — what exists

Lookup tables you can scan in seconds. One row per thing; the row says what it
is, where it runs, and its state. How a thing works belongs on its page in
`systems/`, and the row links there once that page exists.

| File | One row per | Owns |
|---|---|---|
| `services.md` | service or app | the service list |
| `hosts.md` | machine: bare metal, VM, VPS | the host list |
| `network.md` | IP address | every IP and how traffic flows in |

## Rules

- Tables, not prose. If a row needs a paragraph, the paragraph goes in
  `systems/`.
- Each fact appears once. An IP is written in `network.md` only; other tables
  name the host.
- Every table says at the top that its rows are from the docs and not
  verified. A row checked against the live lab names the date and how in its
  State column (`verified: recon 2026-11-02`).
- Unknown is written as `unknown`, never guessed.
- Only private addresses and placeholders. The scan blocks public IPs and
  tailnet names (`repo/secret-scanning.md`).
