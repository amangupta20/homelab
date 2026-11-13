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
  `luci-app-attendedsysupgrade`, `owut`, `tailscale`, `iperf3`,
  `luci-app-statistics`, `luci-app-sqm`. `htop` was already present. Traffic
  shaping was left switched off (`uci show sqm`: `enabled='0'`).
  `luci-app-adblock-fast` was installed and removed again the same evening:
  the owner will block ads elsewhere. The web server was restarted so it created its
  certificate.
- IPv6 on the WAN turned back on (`network.wan.ipv6`, `network.wan6.disabled`
  and `dhcp.lan.ra_default` removed), after a 20-second runtime-only test
  showed the ISP line passing IPv6 again.
- The hourly channel-scan cron line commented out: each scan takes the
  2.4 GHz radio off its channel for a few seconds.

**2026-11-14, just after midnight, same session:**

- Tried to replace the reduced Wi-Fi daemon with the full one from the
  package feed, at the owner's request. A first run removed the old package
  and failed to install the new one from local files (unsigned when
  installed from a file); a second run installed it from the feed, and the
  daemon would not start. Each run took both radios down, for about 75
  seconds each, until a script put the original files back. Wi-Fi is on the
  original daemon again; the package database still names the new one. The
  details and the rule are in `systems/router.md`.
- IPv6 relay mode turned on (`dhcp.wan6` created; `ra`, `dhcpv6`, `ndp` set
  to `relay` on `wan6` and `lan`), because the ISP router delegates no
  prefix and downloads from one content network are slow over IPv4.

- Firmware upgraded to the community release v1.0.1 (kernel 6.18.60) with
  `sysupgrade`, at the owner's request. The image was checked against the
  release notes' SHA-256 and with `sysupgrade -T` first. The router was back
  after about 70 seconds with its settings kept. This also cleared the wrong
  package database left by the failed swap.
- Added packages reinstalled. The Argon theme is not in the feed; it was
  installed from its project's release files and the login page was checked
  to serve it (`curl`).
- The full Wi-Fi daemon installed in place of the image's mesh variant: both
  were the same release this time, and both radios came back in 38 seconds.
  802.11v turned on for both radios (`bss_transition`), 802.11r set off, and
  `usteer` installed.

## Snapshot / backup taken

- 2026-11-12: the stock flash partitions, before flashing (flashing session
  notes). Three partitions could not be read from the running system.
- 2026-11-13: `sysupgrade -b` before the package installs and the settings
  changes of this session; the archive was copied to the owner's workstation
  and its file list read back (39 files).
- 2026-11-13, 23:55: a second `sysupgrade -b`, and an archive of the Wi-Fi
  daemon's files, before the daemon swap. The archive was used twice to roll
  back.
- 2026-11-14, 00:28: a third `sysupgrade -b` and the installed-package list,
  right before the firmware upgrade.

Both are outside this repo (credentials, factory calibration data). Neither
was restored.

## How it was verified

All on 2026-11-13, over SSH or from a laptop on the LAN.

- Internet over IPv4 from the router and the laptop (`ping`, 0% loss).
- IPv6 from the router after the first change: `ifstatus wan6` up, `ping -6`
  to a public host 0% loss, no prefix delegated. After relay mode: the laptop
  has a global IPv6 address and a default route, `ping -6` 0% loss, and the
  `curl` download comparison in `systems/router.md`.
- After the upgrade: `/etc/openwrt_release` and `uname -r` show the new
  build, both radios are on their channels, IPv4 and IPv6 work from the
  router and the laptop, the relay settings and SSH key-only setting are
  still in the config, and the kernel log has no `ath11k` failure.
- After the second daemon swap: `apk list -I` shows `wpad-mbedtls`, the
  running configuration has `bss_transition=1` on both radios, and
  `ubus call usteer local_info` lists both.
- After the daemon rollback: both radios on their channels (`iw dev`), the
  daemon's script file matches its checksum from before, and the laptop
  reconnected.
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
