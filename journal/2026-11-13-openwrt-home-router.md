# 2026-11-13 — OpenWrt on the home router, and its first configuration

**Who:** the owner, with Claude Code (two sessions)  **Scope:** the Home router (`inventory/hosts.md`)  **Mode:** write
**Task:** the owner asked to flash a spare Jio AirFiber indoor unit with OpenWrt and set it up as the home gateway  **Skill:** none

The flash on 2026-11-12 was done in an earlier session; that part is written
from that session's notes and is marked so. The 2026-11-13 part was done and
checked in the session that wrote this entry.

## What changed

**2026-11-12, from the flashing session's notes:**

- Root access on the stock firmware with the community tool `idu-unlock`,
  then a backup of the stock flash partitions.
- OpenWrt installed in two stages: an image that runs from RAM written to
  the idle firmware slot, then `sysupgrade` to the permanent image. The second
  stage merged the two stock slots into one and cannot be undone from the
  running system.
- LAN set to `10.22.33.1/24` with DHCP; WAN on DHCP behind the ISP router;
  timezone set; a root password set and the owner's SSH key installed. Before
  the password was set, the admin interface accepted any password for root;
  it was checked to refuse a wrong one afterwards.
- IPv6 on the WAN turned off, because the ISP line advertised IPv6 that did
  not pass traffic.
- Wi-Fi brought up on both radios, the Argon theme installed, and an hourly
  channel-scan script added that only logs.

**2026-11-13, this session:**

- Wi-Fi: encryption from mixed WPA2/WPA3 to WPA2-PSK on both radios, 5 GHz
  from automatic channel to 149, 2.4 GHz from channel 1 to 6, "Disassociate
  on low acknowledgement" off on both. The owner made these in the web
  interface except the 5 GHz low-acknowledgement setting (`uci set`). The
  reasons are in `systems/router.md`.
- SSH password sign-in is off (`uci show dropbear`); the flashing session's notes had it on, so it was changed between the two sessions.
- Packages installed with `apk add`: `luci-app-nlbwmon`, `luci-ssl`,
  `luci-app-attendedsysupgrade`, `owut`, `tailscale`, `iperf3`. `htop` was
  already present. The web server was restarted so it created its
  certificate.
- IPv6 on the WAN turned back on (`network.wan.ipv6`, `network.wan6.disabled`
  and `dhcp.lan.ra_default` removed), after a 20-second runtime-only test
  showed the ISP line passing IPv6 again.
- The hourly channel-scan cron line commented out: each scan takes the
  2.4 GHz radio off its channel for a few seconds.

## Snapshot / backup taken

- 2026-11-12: the stock flash partitions, before flashing (flashing session
  notes). Three partitions could not be read from the running system.
- 2026-11-13: `sysupgrade -b` before the package installs and the settings
  changes of this session; the archive was copied to the owner's workstation
  and its file list read back (39 files).

Both are outside this repo (credentials, factory calibration data). Neither
was restored.

## How it was verified

All on 2026-11-13, over SSH or from a laptop on the LAN.

- Internet over IPv4 from the router and the laptop (`ping`, 0% loss).
- IPv6 from the router after the change: `ifstatus wan6` up, `ping -6` to a
  public host 0% loss. No prefix is delegated, so the laptop has no global
  IPv6 address and no IPv6 default route (`ip -6 route`).
- Both radios' running configuration shows the low-acknowledgement setting
  off (`/var/run/hostapd-phy*.conf`), and `iw dev` shows channels 6 and 149.
- The web interface answers on HTTPS (`curl -k`), and the packages are listed
  by `apk list -I`. The bandwidth monitor's service is running. Tailscale is
  installed and reports "Logged out".
- Throughput next to the router with `iperf3` from a phone to the laptop:
  437–498 Mbit/s on 5 GHz and 85–96 Mbit/s on 2.4 GHz. An eight-minute watch
  of one ping a second to the phone on 2.4 GHz lost none of 421.

## Still open

- Wi-Fi at the edge of range is still being tested by the owner; nothing is
  concluded here.
- The rest is in `decisions/open-questions.md`, "Home router (OpenWrt)".
