# 2026-11-23 — Technitium DNS on oob-1

**Who:** Claude Code, at the owner's request. **Scope:** `oob-1`. **Mode:** write.
**Task:** step B4b of `agents/plans/home-overhaul.md`, the Pi's resolver. **Skill:** none.

## What changed

- `ansible/oob.yml`: Debian's Docker through the LAN cache, `daemon.json` (cache
  mirror, Docker's firewall rules off) written before the install; Technitium 15.6.2
  (`apps/homeserver/technitium/`, host networking, 640 MB cap); its settings by API:
  HaGeZi Ultimate + TIF Medium, DoH to Cloudflare and Quad9, queries from loopback
  and the home subnet, the (empty) allowlist, a `home.<zone>` wildcard to `proxy-1`.
- Firewall: DNS and the console (5380) from the home subnet; `nftables.conf` now
  replaces only its own table, where `flush ruleset` would have deleted Tailscale's.
- `cgroup_enable=memory` in `/boot/firmware/cmdline.txt` and one reboot, since the cap
  was not enforced; the container was then recreated by hand to take it.
- Admin password created in OpenBao (`kv/homelab/technitium`). No client switched.

## Snapshot / backup taken

None possible; the Pi is rebuilt from this repo. Copies on the Pi before the change:
`/root/nftables.conf.bak-20261123`, `/root/cmdline.txt.bak-20261123`.

## How it was verified

- `--check --diff` read first (no password in it), then applied; later runs
  `changed=0`, before and after the reboot.
- `dig` from agent-1: `example.com` answered, `ads.doubleclick.net` and
  `app-measurement.com` blocked, `cache.home.<zone>` gave the proxy; again after
  the reboot. The API reported 573,538 block-list entries.
- `nft list tables`: Tailscale's six tables kept; `tailscale status --json`:
  `Running`, route primary, after the reboot too.
- Technitium 335 MB resident, 243 MB anonymous; after the reboot `/proc/cgroups`
  lists `memory` and `docker stats` shows the 640 MiB cap.

## Still open

The VPS node, the cluster, DHCP and the tailnet's nameservers, and the IPv6 relay
(B4b); the Pi's power (`agents/decisions/open-questions.md`).
