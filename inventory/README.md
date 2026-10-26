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
- Every row says how it is known: "in docs, not verified" until someone checks
  it against the live lab, then the date and how (`recon 2026-11-02`).
- Unknown is written as `unknown`, never guessed.
- Only private addresses and placeholders. The scan blocks public IPs and
  tailnet names (`repo/secret-scanning.md`).
