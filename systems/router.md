---
type: system
status: "running, behind the ISP router (double NAT)"
verified: "yes (read over SSH 2026-11-13; the flash and recovery notes are from the flashing session's notes)"
hosts:
  - Home router
tags:
  - system
  - router
  - openwrt
  - network
---

# Home router

A Jio AirFiber indoor unit (model JIDU6411) running OpenWrt, an open-source
router operating system, in place of its stock firmware. It is the gateway,
DHCP server and DNS forwarder for the home subnet.

**Status:** running, behind the ISP router (double NAT: the ISP router
translates addresses once and this router does it again). Rows:
`inventory/hosts.md`, `inventory/network.md`, `inventory/services.md`.

## How it works

Read on 2026-11-13 over SSH (`uci show`, `iw dev`, `iwinfo`, `ifstatus`,
`apk list -I`, `/etc/openwrt_release`), unless a line says otherwise.

- **Hardware:** Qualcomm IPQ9554, 512 MB RAM, 256 MB NAND flash, one WAN and
  four LAN gigabit ports (hardware table of `openwrt/openwrt` #26498). Seen
  on the device: 4 cores (`/proc/cpuinfo`), 446 MB usable RAM (`free`), and
  two Wi-Fi 6 radios driven by `ath11k`, 2.4 GHz on the main chip and 5 GHz
  on a separate card, each advertising four antennas (`iw phy`). No Wi-Fi 7.
- **Firmware:** a community OpenWrt snapshot build, revision
  `r35553+1410-fdb162fb81`, kernel 6.18.55, target `qualcommbe/ipq95xx`,
  board name `jiorouter,ax6000-jidu6j11`. The device is not in official
  OpenWrt yet: pull requests `openwrt/openwrt` #26498 and #26551 were both
  open on 2026-11-13 (`gh pr view`).
- **LAN:** `10.22.33.1/24`, DHCP from dnsmasq, leases 12 hours. Addresses are
  in `inventory/network.md`.
- **WAN:** the `wan` port takes a private address by DHCP from the ISP
  router. The firewall masquerades LAN traffic and rejects everything
  arriving on the WAN side. The ISP uses carrier-grade NAT, so nothing is
  forwarded inward (owner, 2026-11-13).
- **IPv6:** on for the router itself since 2026-11-13: it gets an address and
  reaches the internet over IPv6 (`ping -6`, 0% loss). The ISP router does
  not delegate a prefix (`ifstatus wan6` shows none), so LAN devices are
  still IPv4-only. See the open questions.
- **Wi-Fi:** one network name on both radios, WPA2-PSK. 2.4 GHz on channel 6,
  20 MHz wide; 5 GHz on channel 149, 80 MHz wide. "Disassociate on low
  acknowledgement" is off on both (see Rules).
- **Admin access:** SSH with a key only, and the LuCI web interface over HTTP
  and HTTPS (self-signed certificate), both reachable from the LAN only.
- **Added packages:** `luci-app-nlbwmon` (traffic per device, under Status →
  Bandwidth Monitor; its database is in RAM and is written to flash once a
  day, so a reboot can lose up to a day), `luci-ssl`,
  `luci-app-attendedsysupgrade` and `owut` (upgrade helpers, **UNTESTED** on
  this build), `tailscale` (installed, not logged in), `luci-app-statistics`
  (history graphs of load, memory, interfaces and Wi-Fi under Statistics;
  kept in RAM, so a reboot clears them), `luci-app-sqm` (traffic shaping,
  installed and switched off), `iperf3`, `htop`, and the Argon LuCI theme.

### Why the Wi-Fi settings are what they are

Measured on the router on 2026-11-13 (`iw dev <radio> scan`, `logread`).

- **5 GHz on 149, not automatic:** automatic selection picked channel 60, a
  radar-detection channel, where the radio must leave the channel when it
  hears radar. 149 is outside that range and was clear in the scans.
- **2.4 GHz on 6 at 20 MHz:** channel 6 had two weak neighbours; channel 11
  carries the ISP router's own network. A 40 MHz setting is refused by the
  router here (`hostapd`: "20/40 MHz operation not permitted … based on
  overlapping BSSes") and it falls back to 20 MHz.
- **WPA2-PSK, not mixed WPA2/WPA3:** with the mixed mode a phone alternated
  between the two sign-in methods while moving between the radios and
  reconnected repeatedly (`logread`, 2026-11-13).

## Rules

- **A failed firmware upgrade can only be recovered over the serial
  console.** The stock firmware's two-slot layout was merged into one when
  OpenWrt was installed, so there is no second copy to boot. Recovery needs a
  3.3 V UART adapter (voltage from #26551) and the boot loader's console login, which is kept with
  the factory backup (see Backups). **UNTESTED.**
- **Take a config backup before changing firmware or packages:**
  `sysupgrade -b <file>` on the router (run 2026-11-13).
- **Set the netmask whenever the LAN address is changed.** Setting only
  `network.lan.ipaddr` produced a `/32` address, and every IPv4 packet to the
  router was dropped. The way back in was SSH to the router's IPv6
  link-local address (flashing session notes, 2026-11-12).
- **Do not scan from the access-point interfaces while people are using
  Wi-Fi.** `iw dev <ap> scan` takes the radio off its channel for a few
  seconds. An hourly scan script from the flashing session
  (`/usr/bin/chanwatch.sh`) is still on the router; its cron line was
  commented out on 2026-11-13 for this reason.
- **Keep "Disassociate on low acknowledgement" off.** With it on, the router
  disconnected devices at the edge of range instead of slowing down
  (`logread`: "disconnected due to excessive missing ACKs", 2026-11-13).
- **Leave 802.11r (fast roaming) off.** A tester on the upstream pull request
  reports it fails with this driver (#26498, comment of 2026-11-11); not
  tried here.
- **Do not install the full `wpad` Wi-Fi daemon from the package feed.** The
  image ships the reduced `wpad-basic-mbedtls`. The feed's `wpad-mbedtls` is
  built against newer core libraries than this image has
  (`apk info -R`, 2026-11-13: `libucode` and `libubus` of October against
  the image's July and September ones), and a Wi-Fi daemon that fails to
  start leaves only the cable and the serial console. Get it by building it
  into the next firmware image instead. Not tried.
- **An upgrade drops every added package** unless the upgrade helper rebuilds
  the image with them, and that is untested on this build. Reinstall from the
  list above.

## Backups

Not in `systems/backups.md` yet: nothing is scheduled. Two manual copies
exist on the owner's workstation, outside this repo because they hold
credentials and factory calibration data:

- a factory backup of the stock flash partitions, taken before flashing
  (flashing session notes, 2026-11-12). Three partitions could not be read
  from the running system, so it restores stock firmware but is not a
  byte-exact image;
- an OpenWrt config archive from `sysupgrade -b`, taken 2026-11-13.

Neither has been restored. A restore is **UNTESTED**.

## Open questions

`decisions/open-questions.md`, "Home router (OpenWrt)".
