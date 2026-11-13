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
- **Firmware:** the community OpenWrt build for this device, release v1.0.1:
  revision `r35553+2591-fdb162fb81`, kernel 6.18.60, target
  `qualcommbe/ipq95xx`, board name `jiorouter,ax6000-jidu6j11`
  (`/etc/openwrt_release`, `uname -r`, 2026-11-14). The device is not in
  official OpenWrt yet: pull requests `openwrt/openwrt` #26498 and #26551
  were both open on 2026-11-14 (`gh pr view`), and neither publishes images.
- **LAN:** `10.22.33.1/24`, DHCP from dnsmasq, leases 12 hours. Addresses are
  in `inventory/network.md`.
- **WAN:** the `wan` port takes a private address by DHCP from the ISP
  router. The firewall masquerades LAN traffic and rejects everything
  arriving on the WAN side. The ISP uses carrier-grade NAT, so nothing is
  forwarded inward (owner, 2026-11-13).
- **IPv6:** on since 2026-11-13. The ISP router does not delegate a prefix
  (`ifstatus wan6` shows none), so the router runs in relay mode: `odhcpd`
  passes the ISP router's address announcements and neighbour discovery
  through to the LAN (`dhcp.wan6` as master, `ra`, `dhcpv6` and `ndp` set to
  `relay` on both `wan6` and `lan`). A laptop on the LAN got a global address
  and reached a public host with 0% loss (`ping -6`, 2026-11-14). LAN devices
  therefore sit directly on the ISP's IPv6 network; the router's firewall
  still filters what is forwarded to them.
- **Why IPv6 matters on this line:** downloads from the Fastly content
  network are slow over IPv4 and normal over IPv6. Measured from a laptop on
  2026-11-14 with `curl`, 12 seconds each: an OpenWrt image at 49 kB/s over
  IPv4 and 851 kB/s over IPv6; a crates.io file at 1 kB/s and 999 kB/s. In
  the same hour Cloudflare and Google gave 27–40 Mbit/s over either
  (`wget` on the router). GitHub release downloads have no IPv6 address and
  stayed under 1 Mbit/s.
- **Wi-Fi:** one network name on both radios, WPA2-PSK. 2.4 GHz on channel 6,
  20 MHz wide; 5 GHz on channel 149, 80 MHz wide. "Disassociate on low
  acknowledgement" is off on both (see Rules). The full Wi-Fi daemon
  (`wpad-mbedtls`) replaced the image's `wpad-mesh-mbedtls` on 2026-11-14,
  with 802.11k and 802.11v on and 802.11r off. `usteer` runs on top of it
  and sees both radios (`ubus call usteer local_info`); it moves devices
  between the two bands. How well it does that here is untested.
- **Admin access:** SSH with a key only, and the LuCI web interface over HTTP
  and HTTPS (self-signed certificate), both reachable from the LAN only.
- **Added packages:** `luci-app-nlbwmon` (traffic per device, under Services →
  Bandwidth Monitor; its database is in RAM and is written to flash once a
  day, so a reboot can lose up to a day), `luci-ssl`,
  `luci-app-attendedsysupgrade` and `owut` (upgrade helpers, **UNTESTED** on
  this build), `tailscale` (see Tailscale below), `luci-app-statistics`
  (history graphs of load, memory, interfaces and Wi-Fi under Statistics;
  kept in RAM, so a reboot clears them), `luci-app-sqm` (traffic shaping,
  installed and switched off), `wpad-mbedtls`, `usteer` with
  `luci-app-usteer`, `iperf3` and `htop`. The Argon LuCI theme (3.1.4) is not in the
  package feed: its two `.apk` files come from the theme project's GitHub
  releases and are installed with `apk add --allow-untrusted`.

- **Tailscale:** the router is signed in to the tailnet and is the subnet
  router for the home subnet: it advertises the subnet and the route is
  approved (`tailscale status --json`, 2026-11-14), so tailnet devices can
  reach LAN machines that do not run Tailscale themselves. It does not take
  DNS settings from the tailnet. A firewall zone `tailscale`, attached to
  the device `tailscale0`, accepts traffic from the tailnet and forwards
  between it and the LAN; who on the tailnet may use that is set by the
  tailnet's access rules, kept in the private repo. Reaching a LAN machine
  from outside through it is **UNTESTED**.
- **Detour for GitHub downloads:** the router accepts routes from the
  tailnet, and the Remote VPS advertises the address range GitHub serves
  release and raw files from, so that traffic would leave through the VPS
  instead of the slow IPv4 path (see "Why IPv6 matters"). On 2026-11-14 the
  VPS advertised the range and it was not yet approved in the admin console,
  so the router still sent that traffic out of its own WAN (`ip route get`).
  **UNTESTED.** The range itself is not written here: the secret scan
  rejects public addresses.

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
  `sysupgrade -b <file>` on the router (run 2026-11-13 and 2026-11-14).
- **Upgrading between community releases:** copy the release's
  `squashfs-sysupgrade.bin` to `/tmp`, compare its SHA-256 with the release
  notes, run `sysupgrade -T` on it, then `sysupgrade -v`. Run once,
  2026-11-14, from the 2026-09 build to v1.0.1: the router answered again
  after about 70 seconds with its settings kept. Afterwards reinstall the
  added packages; `/root` is wiped too.
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
- **Install Wi-Fi packages (`wpad`, `hostapd-common`, `wifi-scripts`) from
  the feed only when their versions match the image's.** The feed is a
  moving snapshot. On the previous firmware it had moved ahead of the image,
  and on 2026-11-14 the feed's full daemon would not start there (`logread`:
  "common.uc does not export 'macaddr_keep'"); both radios were down for
  about 75 seconds, twice, until the old files were put back from an
  archive. On v1.0.1 the image and the feed carried the same release
  (`apk list -I`, `apk add --simulate`), and the swap worked. Before any such
  change: compare versions, archive the current daemon's files, and have a
  script restore them if the radios do not come back.
- **Attach the Tailscale firewall zone to the device, not to a network
  interface.** Declaring `tailscale0` as an interface in `/etc/config/network`
  made the next `network reload` empty Tailscale's routing table, and the
  router then sent tailnet traffic out of its WAN until Tailscale was
  restarted (`ip route show table 52`, 2026-11-14). With the zone's `device`
  option instead, the routes survived a reload (checked the same day).
- **Do not run `apk upgrade`.** It pulls everything to the feed's newer
  versions, the same mismatch on a larger scale. Kernel modules never come
  from the feed: this build's kernel does not match it, and the release
  ships its own module archive.
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
