# 2026-11-22 — Home router: slow Tailscale forwarding found and worked around

**Who:** Claude Code (Opus 5.5), on `agent-1`  **Scope:** Home router (OpenWrt), Tailscale  **Mode:** write
**Task:** owner, in session: find why traffic the router forwards between the tailnet and the LAN runs at
about 0.1 MB/s  **Skill:** none

## What changed

- Router: `tcpdump` and `libpcap1` installed (`apk add --simulate` read first: no kernel modules).
- Router: `/etc/init.d/tailscale` got `procd_append_param env TS_TUN_DISABLE_TCP_GRO=true` with a comment, and
  tailscaled was restarted. The unchanged file is `/root/tailscale.init.orig`. Undo: delete the line and
  restart. Why: `lab/systems/notes/router.md`, "Tailscale forwarding bug".
- Remote VPS: `tcpdump` installed from Ubuntu (owner's OK in session); test servers and files removed after.
- `agent-1`: `iperf3`, `mtr-tiny` and `udhcpc` installed; the test network namespace was deleted, and GRO
  on its LAN interface, off for some captures, was turned back on (`ethtool -k eth0`).

## Snapshot / backup taken

Router config archives (`sysupgrade -b`), one before each router change, on `agent-1` outside the repo (they
hold credentials): `~/router-backups/cfg-2026-11-22-pre-tcpdump.tar.gz` and `cfg-2026-11-22-pre-tcp-gro.tar.gz`,
61 files each (`tar tzf`). Not restored.

## How it was verified

- Tailnet to a LAN client through the router: 0.07–0.11 MB/s before, 5.05 and 4.63 MB/s after; LAN to
  tailnet 4.86 MB/s (`curl` and a small Python sender, VPS to a test namespace on `agent-1`).
- tailscaled's environment holds the setting (`/proc/<pid>/environ`), the router is online in the tailnet
  and table 52 has its 9 routes again (`ip route show table 52`).
- GitHub release through the detour from `agent-1`: 4.6–4.7 MB/s over three 15-second runs.
- Router CPU during a 4.8 MB/s tailnet download: 5–7% busy before, 8% after.
- Detour against GitHub's range over the WAN (a temporary `ip rule`, deleted after, `ip rule` checked): detour
  4.6–4.7 MB/s, direct 2.0–5.0 MB/s, so the detour stays.

## Still open

- Reporting the driver bug upstream: set aside by the owner for now.
- The init-script line is lost on a `tailscale` reinstall or firmware upgrade (`lab/systems/router.md`, Rules).
