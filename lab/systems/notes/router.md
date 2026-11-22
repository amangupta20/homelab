# Home router — notes

Measurements, reasons and lists behind `lab/systems/router.md`.

## Why IPv6 matters

- **Why IPv6 matters on this line:** downloads from the Fastly content
  network are slow over IPv4 and normal over IPv6. Measured from a laptop on
  2026-11-14 with `curl`, 12 seconds each: an OpenWrt image at 49 kB/s over
  IPv4 and 851 kB/s over IPv6; a crates.io file at 1 kB/s and 999 kB/s. In
  the same hour Cloudflare and Google gave 27–40 Mbit/s over either
  (`wget` on the router). GitHub release downloads have no IPv6 address and
  stayed under 1 Mbit/s.

## Added packages

- **Added packages:** `luci-app-nlbwmon` (traffic per device, under Services →
  Bandwidth Monitor; its database is in RAM and is written to flash once a
  day, so a reboot can lose up to a day), `luci-ssl`,
  `luci-app-attendedsysupgrade` and `owut` (upgrade helpers, **UNTESTED** on
  this build), `tailscale` (see Tailscale in `lab/systems/router.md`), `luci-app-statistics`
  (history graphs of load, memory, interfaces and Wi-Fi under Statistics;
  kept in RAM, so a reboot clears them), `luci-app-sqm` (traffic shaping,
  installed and switched off), `wpad-mbedtls`, `usteer` with
  `luci-app-usteer`, `iperf3`, `htop`, and `tcpdump` (added 2026-11-22 to
  find the Tailscale forwarding bug; it pulls in `libpcap1`). The Argon LuCI theme (3.1.4) is not in the
  package feed: its two `.apk` files come from the theme project's GitHub
  releases and are installed with `apk add --allow-untrusted`.


## Detour test

Tested
  2026-11-14 after the owner approved the route: a 19 MB release file took
  4 seconds from the router (`wget -4`) and ran at 4.6–4.7 MB/s from a
  laptop whose traffic went through the router (`curl --interface`). Before
  the detour the same file had reached 3.7 MB in 500 seconds from that
  laptop.

## Wi-Fi daemon swap

Moved here from `lab/systems/router.md`, Rules, on 2026-11-22 to keep that page
under its length cap. On the previous firmware the feed had moved ahead of the
image, and on 2026-11-14 the feed's full daemon would not start there
(`logread`: "common.uc does not export 'macaddr_keep'"); both radios were down
for about 75 seconds, twice, until the old files were put back from an
archive. On v1.0.1 the image and the feed carried the same release
(`apk list -I`, `apk add --simulate`), and the swap worked.

## Tailscale forwarding bug

Found and worked around on 2026-11-22. The setting and the rule are in
`lab/systems/router.md` ("Tailscale's TCP coalescing is off", and Rules).

- **Symptom:** TCP from the tailnet to a LAN machine through the router ran at
  0.07–0.11 MB/s. The same sender reached a tailnet device directly, and the
  router itself, at about 4.8 MB/s, and LAN to tailnet through the router also
  ran at 4.8 MB/s. Measured with a small Python sender and receiver and `curl`
  between the Remote VPS and a test network namespace on `agent-1` (a macvlan
  on its LAN interface with its own DHCP lease, so the traffic went through
  the router and not through `agent-1`'s own Tailscale). The tailnet's access
  rules only let the VPS reach one port on the LAN, so the namespace opened
  the connections.
- **Not the line or the ISP router:** with `tcpdump` on both ends, the VPS
  sent 613 full-size tunnel packets and the router's WAN received 609. Every
  inner TCP segment the VPS sent appeared on the router's `tailscale0`,
  `br-lan` and `lan1`, and every ACK came back. Nothing on the router counted
  a drop: interface, qdisc, UDP and firewall counters were all flat.
- **Where it went wrong:** the sender kept stalling for about 215 ms, its
  minimum retransmission timeout, and the receiver's SACKs showed holes the
  size of whole merged packets. On `tailscale0`, `br-lan` and `lan1` about one
  packet in six was a 2- or 3-segment GSO packet (2508 or 3736 bytes)
  written by tailscaled, yet `lan1`'s hardware TSO counter
  (`ethtool -S lan1`, `tx_tso_packets`) did not move during the transfer.
  A capture on `agent-1` cannot show what was on the wire: it is a Xen VM,
  and its host merges packets before the VM sees them.
- **Why:** the EDMA transmit code
  (`target/linux/qualcommbe/patches-6.18/0334-net-ethernet-qualcomm-Add-Tx-Ethernet-DMA-support.patch`
  in `openwrt/openwrt`, read 2026-11-22) turns on hardware TSO only when
  `skb_shinfo(skb)->gso_type == SKB_GSO_TCPV4` (or `_TCPV6`). `gso_type` is a
  set of flags. Packets that a program writes into a TUN device also carry
  `SKB_GSO_DODGY`, so the test fails and the merged packet goes out as one
  frame. Packets the router's own TCP builds have only the plain flag, which
  is why everything else works. The unified driver
  (`carlgsmith/qcom-ppe`, `edmav2/tx.c`) has the same line, and mainline
  Linux has only the PPE core, not EDMA. No bug report was found (searches of
  `openwrt/openwrt` and the community firmware repository's issues,
  2026-11-22). The fix in the driver is to test the flags with `&`; that
  needs a kernel build, not done.
- **Workaround and its cost:** `TS_TUN_DISABLE_TCP_GRO=true` makes tailscaled
  write ordinary single-segment packets. Afterwards: tailnet to LAN client
  5.05 and 4.63 MB/s, LAN to tailnet 4.86 MB/s. Router CPU during a 4.8 MB/s
  tailnet download went from 5–7% to 8% busy over its four cores, and
  tailscaled from 77–80 to 82 ms of CPU per MB (`/proc/stat` and
  `/proc/<pid>/stat` around a 10-second `wget`). Tailscale turns coalescing on
  by default for multi-gigabit tunnels, where the per-packet cost matters;
  this line tops out near 5 MB/s.
- **Restoring the setting** after a `tailscale` reinstall or upgrade, or a
  firmware upgrade, which replace `/etc/init.d/tailscale`: add
  `procd_append_param env TS_TUN_DISABLE_TCP_GRO=true` under the line that
  sets `TS_NO_LOGS_NO_SUPPORT`, run `/etc/init.d/tailscale restart`, and check
  the running daemon with
  `tr '\0' '\n' < /proc/$(pidof tailscaled)/environ | grep TS_TUN`
  (all run 2026-11-22). To undo: delete the line and restart.
- **GitHub detour afterwards:** a GitHub release from `agent-1` ran at
  4.6–4.7 MB/s through the detour and at 4.9 MB/s from two other Fastly
  addresses over the plain WAN path (`curl --resolve`, three 15-second runs
  each). GitHub's own range over the WAN was not measured, so whether the
  detour is still needed is open.
- **Tried earlier without effect** (handoff notes, 2026-11-23): UDP GRO
  forwarding on `wan` (`ethtool -K wan rx-udp-gro-forwarding on
  rx-gro-list off`, reverted). MSS clamping (`mtu_fix`), masquerading and
  `rp_filter` were already as they should be.

## Why the Wi-Fi settings are what they are

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
