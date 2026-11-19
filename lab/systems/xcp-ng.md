---
type: system
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
pool. The host's hardware was checked at the console ("Hardware" below). Rows: `lab/inventory/hosts.md`, `lab/inventory/services.md`.

How VMs and XO itself are backed up: `lab/systems/backups.md`.

## The one rule that destroys VMs

> [!WARNING] Never delete an XCP-ng base snapshot by hand
> It can be a link in the live disk chain. Merge or delete only through the Xen
> Orchestra web UI, with a verified backup first.

What happens if you break it: the VM's disk chain breaks and the VM is
unbootable. This happened in July 2026 — manual snapshot handling destroyed
VMs, TrueNAS backups recovered data but the XO instances were lost (~2 days
of work).

## Hardware

Read by the owner at the machine (`agents/journal/2026-11-13-xcp-ng-host-ram-and-bios.md`);
the memory total has not yet been read from XCP-ng itself. How each fact was
found, the tests behind them and the manual's slot names: `lab/systems/notes/xcp-ng.md`.

| Part | What |
|---|---|
| Motherboard | Gigabyte B450M DS3H (the plain model: not the V2, not the WIFI) |
| CPU | AMD Ryzen 5 1600, 6 cores / 12 threads |
| Memory | 40 GB: two 16 GB sticks and one 8 GB stick, DDR4, running at 2400 MHz |
| BIOS | updated by the owner (`agents/journal/2026-11-13-xcp-ng-host-ram-and-bios.md`); the version is not recorded here |

### Memory layout

A memory channel is one set of wires from the CPU to the memory. This board
has two channels, A and B, with two slots on each.

| Slot (BIOS name) | Position, counting from the CPU | Holds |
|---|---|---|
| DDR4_A1 | 1st | 8 GB |
| DDR4_A2 | 2nd | empty |
| DDR4_B1 | 3rd | 16 GB |
| DDR4_B2 | 4th | 16 GB |

> [!WARNING] The 8 GB stick must be alone on its channel
> If it shares a channel with either 16 GB stick, the board cannot start that
> channel. It then drops both sticks on it and hands the operating system
> only 16 GB, while the BIOS still lists the full 40 GB.

- **The BIOS total is not the usable total.** Read the real figure from
  Memtest86+ or from an operating system.
- **If the total ever drops to 16 GB:** shut down, check the layout against
  the table above, clear CMOS with the `CLR_CMOS` pins (about 30 seconds;
  "Load Optimized Defaults" is not enough), then set the BIOS settings below
  again. Lowering the memory speed does not help.

Checking the total from XCP-ng (**UNTESTED** on this host):
`xl info | grep total_memory`. Expect about 40900, in MB.

### BIOS settings this host depends on

A CMOS clear or a BIOS update puts all of these back to their defaults.

| Setting | Where in the BIOS | Value | Why |
|---|---|---|---|
| SVM Mode | M.I.T. → Advanced Frequency Settings → Advanced CPU Core Settings | Enabled | hardware virtualisation; XCP-ng cannot run VMs without it |
| IOMMU | Peripherals → AMD CBS → NBIO Common Options | Enabled | lets a VM be given a physical device |
| System Memory Multiplier | M.I.T. → Advanced Memory Settings | Auto | Auto picks 2400 MHz, the 8 GB stick's rated speed |

The SVM Mode and IOMMU locations are from memory, unverified.

### Until the thermal paste is replaced

The CPU's thermal paste has dried out and the cooler is stuck to the CPU, so
the owner set these to keep it below its limit (why, and the temperatures:
notes page). A CMOS clear turns both back; set them again after one.

| Setting | Where in the BIOS | Set to | Put back to |
|---|---|---|---|
| CPU fan speed | M.I.T. → Smart Fan 5 Settings → CPU_FAN → Fan Speed Control | Full Speed | Normal |
| Core Performance Boost | M.I.T. → Advanced Frequency Settings → Advanced CPU Core Settings | Disabled | Auto |

The two menu locations are from memory, unverified.
