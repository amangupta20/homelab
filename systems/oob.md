---
type: system
status: "running, subnet router on its own tailnet"
verified: "yes (over SSH and tailscale status 2026-11-14; route tested by the owner from a device on the second tailnet)"
hosts:
  - oob-1
tags:
  - system
  - network
  - tailscale
  - recovery
---

# Out-of-band box (oob-1)

A Raspberry Pi that is a second way into the home LAN, for the day the main
way in is broken.

**Status:** running since 2026-11-14 — subnet router for the home subnet on a
second Tailscale account. Rows: `inventory/hosts.md`, `inventory/network.md`.
Story: `journal/2026-11-14-rebuild-oob-pi.md`.

## Why it exists

The main way in from outside is the Home router's Tailscale subnet route
(`systems/router.md`, "Tailscale"). If the router's Tailscale stops, or a
change to the main tailnet's access rules or keys goes wrong, nothing at home
can be reached until someone is in the house. `oob-1` covers that: it is on a
**separate Tailscale account** (its own tailnet), so nothing done to the main
tailnet can lock it out. The account's name is not recorded in this repo.

What it does not cover: the Home router itself dying. `oob-1` is plugged into
the router's LAN, so it goes down with it. Connecting its Wi-Fi to the ISP
router as a second uplink would cover that; not done (owner, 2026-11-14).

## How it works

Read on 2026-11-14 over SSH unless a line says otherwise.

- **Hardware:** Raspberry Pi 3 Model B Plus Rev 1.3, 1 GB RAM, 29 GB SD card
  (`/proc/device-tree/model`, `free`, `lsblk`).
- **Power:** the old adapter caused undervoltage — 21 "Undervoltage
  detected" kernel messages in one boot. With a new adapter on the same cable:
  none, including one minute with all four cores busy (`journalctl -k`,
  `/sys/class/hwmon/*/in0_lcrit_alarm`). The cable is fine.
- **OS:** Raspberry Pi OS Lite 64-bit, image `2026-10-06-raspios-trixie-arm64-lite`
  (Debian 13), kernel `6.18.50+rpt-rpi-v8` (`/etc/os-release`, `uname -r`).
- **Network:** static `10.22.33.252/24`, gateway and DNS the Home router, set
  by cloud-init's `network-config` at first boot. The address is outside the
  router's DHCP pool.
- **First boot (cloud-init):** the image's boot partition carries a
  `user-data` (hostname `oob-1`, user `aman` with the two keys below, password
  login off, root locked) and `network-config`. Nothing else is set there;
  everything after first boot is Ansible. cloud-init reports one harmless
  warning: the image's own config names a module, `cc_netplan_nm_patch`,
  that is not installed (`cloud-init status --format json`).
- **Configuration (Ansible):** `ansible/oob.yml`, run from the workstation. It
  sets:
  - SSH: keys only, no root login (`sshd -T`).
  - Keys: exactly two, both kept in `ansible/files/`. `breakglass.pub` is
    the emergency key: its private half has a copy offline, kept by the owner.
    `workstation.pub` is the daily key until the lab has an SSH certificate
    authority in OpenBao (planned, not started).
  - Firewall (`nftables`): in, only SSH, Tailscale's UDP port 41641 and the
    tailnet itself; forwarding only to and from the tailnet.
  - Automatic security updates (`unattended-upgrades`).
  - Tailscale from its own package repository (1.104.7 on 2026-11-14),
    advertising `10.22.33.0/24`.
- **Tailscale:** signed in to the second account; the route is approved and
  primary, and key expiry is off (`tailscale status --json`). It does not
  accept other machines' routes. Tailscale warns that UDP forwarding on `eth0`
  is not tuned (UDP GRO); that only limits throughput and was left.
- **Reboot:** after a power cycle the firewall, Tailscale and the route came
  back without help (checked 2026-11-14).

## Why these keys

- **Not keys published on GitHub.** Syncing `authorized_keys` from
  `github.com/<user>.keys` was considered and dropped (2026-11-14): a key added to
  GitHub also logs in to the GitHub account, and GitHub would then decide which keys
  every machine accepts.
- **Break-glass key** for the machines that must work when everything else is broken
  (this Pi, later the router), with an offline copy kept by the owner.
- **Later:** short-lived SSH certificates from OpenBao's SSH secrets engine for daily
  use (not set up). The break-glass key stays, because OpenBao runs on the VPS and is
  reached over the main tailnet — exactly what may be down when this box is needed.

## Using it

On a laptop or phone, switch the Tailscale client to the second account, then
reach LAN addresses directly (for example `10.22.33.1`). SSH to the Pi itself:
`ssh -i ~/.ssh/breakglass_ed25519 aman@10.22.33.252`.

## Rebuild

1. Write a fresh Raspberry Pi OS Lite 64-bit image to the card, with
   `user-data` and `network-config` on its boot partition as described above.
   On 2026-11-14 the image was streamed onto the running Pi's own card over
   SSH (`journal/2026-11-14-rebuild-oob-pi.md`); a card reader and Raspberry
   Pi Imager work as well.
2. From `ansible/`: `ansible-playbook oob.yml --check --diff`, read it, then
   `ansible-playbook oob.yml`. A second run should report `changed=0`.
3. Log in to the second account: either set `TS_AUTHKEY` for the playbook, or
   run `sudo tailscale up --advertise-routes=10.22.33.0/24 --hostname=oob-1`
   on the Pi and open the link it prints. Then approve the route and turn off
   key expiry in that account's admin console, and remove the old machine.

## Rules

- **Never run anything else on it.** It is the way in when other things are
  broken; every extra service is one more thing that can break it or fill its
  memory.
- **Change it through `ansible/oob.yml`**, not by hand, so a rebuild gives the
  same box.

## Backups

None needed: it holds no data. It is rebuilt from this repo (above).
