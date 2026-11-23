# 2026-11-23 — Two-way DNS cluster, query logs, tailnet nameservers

**Who:** Claude Code and the owner. **Scope:** `oob-1`, the tailnet's DNS settings.
**Mode:** write. **Task:** B4b of `agents/plans/home-overhaul.md`. **Skill:** none.

## What changed

- `oob-1`, by `ansible/oob.yml`: Tailscale set to `--netfilter-mode=nodivert`, with
  the subnet route's masquerade moved into `nftables.conf`, so the Pi can reach the
  VPS node (`lab/systems/notes/oob.md`, "Tailscale's firewall").
- Technitium's "Query Logs (Sqlite)" app installed by API, then kept by
  `ansible/oob.yml`: in memory, two days or 10,000 records; the cluster copied it to
  the VPS node.
- The owner, in Tailscale's admin console: the tailnet's global nameservers are the
  Pi's LAN address and the VPS node, with "Override local DNS" on.

## Snapshot / backup taken

On the Pi: `/root/iptables-before-nodivert-20261123.txt`,
`/root/nft-before-nodivert-20261123.txt`.

## How it was verified

- `oob.yml` applied; later runs `changed=0`. `tailscale debug prefs` shows
  `NetfilterMode: 1`; no `ts-` jumps in `INPUT` or `POSTROUTING`; the route `Running`.
- The Pi reaches the VPS's cluster port (200); both nodes list each other as
  `Connected`; a whole-cluster stats call answered in 35 ms.
- Query logs: entries appear by API; the `.db` file on the card did not change.
- agent-1: `tailscale dns status` lists both nameservers, and its system resolver
  refuses `ads.doubleclick.net`.

## Still open

The out-of-band route from a device on the second tailnet: to be tested by the
owner. The IPv6 relay gap (B4b).
