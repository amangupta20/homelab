# 2026-11-14 — rebuilt the Raspberry Pi as the out-of-band box

**Who:** the owner, with Claude Code  **Scope:** the Raspberry Pi at `10.22.33.252`, now `oob-1`  **Mode:** write
**Task:** give the lab a second way in that does not depend on the main tailnet, before the owner leaves the LAN  **Skill:** none

## What was there

A read-only audit over SSH (`systemctl`, `docker ps`, `ss -tulpn`, `nft list ruleset`, crontabs, `/etc` changes), kept
outside this repo. The Pi ran Debian 12 with Pi-hole 5 and Unbound, PiVPN WireGuard (no longer reachable from outside:
the ISP uses carrier-grade NAT), Tailscale in a test container (`authkey-test`, no routes), Uptime Kuma, a Portainer agent,
and daily SD-card image jobs to a TrueNAS share whose mount failed at boot. Nothing on the LAN used it for DNS (owner).
The owner decided none of it was worth keeping.

## What changed

- **Power:** the adapter was replaced. Before: 21 undervoltage messages in one boot. After, same cable: none, including
  one minute with all four cores busy.
- **Reinstalled in place, without a card reader:** Raspberry Pi OS Lite 64-bit (`2026-10-06-raspios-trixie-arm64-lite`,
  checksum verified) was given cloud-init files (`user-data`, `network-config`) on its boot partition, then streamed onto the
  running Pi's own card over SSH: services stopped, the root filesystem made read-only with SysRq `u`, `dd` from the stream,
  SysRq `s` and `b` to reboot. It came up as `oob-1` on the first try.
- **New break-glass SSH key** (`ansible/files/breakglass.pub`); the owner keeps the private half with an offline copy.
- **Configured with `ansible/oob.yml`** (new): keys-only SSH, no root login, `nftables` firewall, automatic security
  updates, Tailscale advertising `10.22.33.0/24`. `ansible/base.yml` now runs only on the `oci` group, so its
  Oracle-specific firewall tasks cannot reach the Pi.
- **Tailscale:** signed in to a second account. The old `authkey-test` machine was removed from that account so `oob-1`
  could take the route; the route was approved and key expiry turned off (owner, in the admin console).
- Everything else above is gone with the old system: Pi-hole, Unbound, WireGuard, Uptime Kuma, the Portainer agent and the
  image jobs.

Facts are in `systems/oob.md`, `inventory/hosts.md` and `inventory/network.md`.

## Snapshot / backup taken

None, on purpose: nothing on the card was worth keeping (owner, 2026-11-14). The audit output is the record of what it ran.

## How it was verified

- After first boot: hostname, Debian 13, static address, root partition grown to 29 GB, login with the break-glass key
  (`hostname`, `ip -br a`, `df -h`).
- `ansible-playbook oob.yml` applied; a second run reported `changed=0`.
- `sshd -T` shows password and keyboard-interactive login off and root login off; `nft list ruleset` shows the drop
  policies; `nftables`, `tailscaled` and `unattended-upgrades` active.
- `tailscale status --json`: running, `10.22.33.0/24` primary on `oob-1`, key expiry off.
- The owner reached the LAN through `oob-1` from a device on the second account.
- After a power cycle, all of the above came back without help.

## Still open

- Adding a passphrase to the break-glass key (owner).
- A Wi-Fi uplink to the ISP router, so `oob-1` survives the Home router failing (not decided).
- Moving the daily key to certificates from an SSH certificate authority in OpenBao (planned).
- A new DNS resolver and a fresh Uptime Kuma, as part of the home overhaul.
