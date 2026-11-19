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
  `luci-app-usteer`, `iperf3` and `htop`. The Argon LuCI theme (3.1.4) is not in the
  package feed: its two `.apk` files come from the theme project's GitHub
  releases and are installed with `apk add --allow-untrusted`.


## Detour test

Tested
  2026-11-14 after the owner approved the route: a 19 MB release file took
  4 seconds from the router (`wget -4`) and ran at 4.6–4.7 MB/s from a
  laptop whose traffic went through the router (`curl --interface`). Before
  the detour the same file had reached 3.7 MB in 500 seconds from that
  laptop.

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
