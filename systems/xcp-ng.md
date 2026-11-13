---
type: system
status: "running, stable (from docs, not checked live)"
verified: "partially (host hardware checked at the console 2026-11-13; pool from docs, not checked live)"
hosts:
  - XCP-ng host
tags:
  - system
  - hypervisor
  - xcp-ng
  - xen-orchestra
---

# XCP-ng & Xen Orchestra

XCP-ng is the hypervisor (the layer that runs VMs on bare metal). Xen
Orchestra (XO) is its web UI — start/stop VMs, take snapshots, schedule
backups. This pair is the base everything else sits on.

**Status:** running, stable — from the docs, not yet checked against the live
pool. The host's hardware was checked at the console on 2026-11-13
("Hardware" below). Rows: `inventory/hosts.md`, `inventory/services.md`.

How VMs and XO itself are backed up: `systems/backups.md`.

## The one rule that destroys VMs

> [!WARNING] Never delete an XCP-ng base snapshot by hand
> It can be a link in the live disk chain. Merge or delete only through the Xen
> Orchestra web UI, with a verified backup first.

What happens if you break it: the VM's disk chain breaks and the VM is
unbootable. This happened in July 2026 — manual snapshot handling destroyed
VMs, TrueNAS backups recovered data but the XO instances were lost (~2 days
of work).

## Hardware

**Source:** everything in this section was read by the owner at the machine
on 2026-11-13 (BIOS screens, Memtest86+ 9.00, a live Linux USB stick), with
Claude Code advising. The work is in
[`journal/2026-11-13-xcp-ng-host-ram-and-bios.md`](../journal/2026-11-13-xcp-ng-host-ram-and-bios.md).
XCP-ng was started on this layout the same evening (owner); the memory total
has not yet been read from XCP-ng itself.

| Part | What |
|---|---|
| Motherboard | Gigabyte B450M DS3H (the plain model: not the V2, not the WIFI) |
| CPU | AMD Ryzen 5 1600, 6 cores / 12 threads |
| Memory | 40 GB: two 16 GB sticks and one 8 GB stick, DDR4, running at 2400 MHz |
| BIOS | updated on 2026-11-13; the version is not recorded here |

### Memory layout

A memory channel is one set of wires from the CPU to the memory. This board
has two channels, A and B, with two slots on each.

| Slot (BIOS name) | Position, counting from the CPU | Holds |
|---|---|---|
| DDR4_A1 | 1st | 8 GB |
| DDR4_A2 | 2nd | empty |
| DDR4_B1 | 3rd | 16 GB |
| DDR4_B2 | 4th | 16 GB |

The BIOS and the manual name the slots differently. The manual's order from
the CPU is DDR4_4, DDR4_2, DDR4_3, DDR4_1, with channel A being DDR4_4 and
DDR4_2 ([manual, page 9](https://download.gigabyte.com/FileList/Manual/mb_manual_b450m-ds3h_e_1101.pdf)).
That the BIOS names follow the same physical order is an assumption: it fits
every reading taken, but nobody traced it on the board.

With this layout Memtest86+ showed 40 GB usable at about 24 GB/s and one full
pass finished with no errors. The manual only lists two-stick and four-stick
layouts; three sticks is outside what it documents.

> [!WARNING] The 8 GB stick must be alone on its channel
> If it shares a channel with either 16 GB stick, the board cannot start that
> channel. It then drops both sticks on it and hands the operating system
> only 16 GB, while the BIOS still lists the full 40 GB. Tried on 2026-11-13
> with the 8 GB stick sharing channel A and sharing channel B, each time with
> one 16 GB stick, with the same result.

- **The BIOS total is not the usable total.** It adds up the sticks it
  detects. Read the real figure from Memtest86+ or from an operating system.
- **A failed layout sticks.** After the 8 GB stick had been in the wrong
  place, the two 16 GB sticks stayed at 16 GB even with it removed.
  "Load Optimized Defaults" did not fix that; shorting the `CLR_CMOS` pins
  for about 30 seconds did.
- **If the total ever drops to 16 GB:** shut down, check the layout against
  the table above, clear CMOS with the `CLR_CMOS` pins, then set the BIOS
  settings below again.
- **Lowering the memory speed does not help.** With a manual 2133 MHz and the
  8 GB stick sharing a channel, the board restarted a couple of times and fell back to
  its automatic setting.

Checking the total from XCP-ng (**UNTESTED** on this host):
`xl info | grep total_memory`. Expect about 40900, in MB.

### BIOS settings this host depends on

A CMOS clear or a BIOS update puts all of these back to their defaults.

| Setting | Where in the BIOS | Value | Why |
|---|---|---|---|
| SVM Mode | M.I.T. → Advanced Frequency Settings → Advanced CPU Core Settings | Enabled | hardware virtualisation; XCP-ng cannot run VMs without it |
| IOMMU | Peripherals → AMD CBS → NBIO Common Options | Enabled | lets a VM be given a physical device |
| System Memory Multiplier | M.I.T. → Advanced Memory Settings | Auto | Auto picks 2400 MHz, the 8 GB stick's rated speed |

The System Memory Multiplier location was read off the screen on 2026-11-13.
The SVM Mode and IOMMU locations are from memory; the owner found and enabled
both that day.

### Temporary: settings to undo after the thermal paste is replaced

The thermal paste between CPU and cooler is the original and has dried out.
On 2026-11-13, with every core loaded from a live Linux USB stick, the CPU
reached 91 °C (`sensors`, `k10temp` `Tctl`); its limit is 95 °C (AMD's figure
for this CPU, from memory, unverified).
The cooler could not be removed that day because the dried paste holds it to
the CPU. Until the paste is replaced, the owner set:

| Setting | Where in the BIOS | Set to | Put back to |
|---|---|---|---|
| CPU fan speed | M.I.T. → Smart Fan 5 Settings → CPU_FAN → Fan Speed Control | Full Speed | Normal |
| Core Performance Boost | M.I.T. → Advanced Frequency Settings → Advanced CPU Core Settings | Disabled | Auto |

Core Performance Boost lets the CPU run above its base 3.2 GHz, up to
3.6 GHz, at the cost of more heat. With it off the CPU is slower at peak; how
much, and how many degrees the two settings save, was not measured.

The two menu locations are from memory, unverified. A CMOS clear silently
turns both settings back to their defaults. Until the paste is
replaced, set them again after any CMOS clear.
