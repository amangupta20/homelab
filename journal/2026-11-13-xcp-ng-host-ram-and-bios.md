# 2026-11-13 — XCP-ng host: all 40 GB of memory usable, BIOS updated

**Who:** the owner at the machine, with Claude Code advising  **Scope:** the XCP-ng host (hardware and BIOS only; no VM touched)  **Mode:** write
**Task:** the host has 16 + 16 + 8 GB of memory but showed 32 GB; find out why and get to 40 GB  **Skill:** none

## What changed

- **Memory layout.** The two 16 GB sticks now share channel B and the 8 GB stick sits alone on channel A. All 40 GB is usable. The
  layout, and the rule behind it, are in [`systems/xcp-ng.md`](../systems/xcp-ng.md), "Memory layout".
- **BIOS updated** with the board's own flashing tool (Q-Flash) from a USB stick. Before flashing, the file on the stick was compared
  with the download (`sha256sum`, identical) and its checksum matched the one the maker lists for that release. The version is not
  recorded in this repo.
- **CMOS cleared** several times by shorting the `CLR_CMOS` pins. Each clear resets every BIOS setting.
- **BIOS settings set again afterwards:** SVM Mode and IOMMU enabled; memory speed left on Auto (2400 MHz).
- **Two temporary BIOS settings to keep the CPU cooler:** CPU fan at full speed and Core Performance Boost disabled. Both are to be
  undone once the thermal paste is replaced (`systems/xcp-ng.md`, "Temporary").
- `inventory/hosts.md`: the XCP-ng host row now names the hardware.

## What was found

- The memory was worse than reported. With the sticks one per channel plus the 8 GB stick, the BIOS listed 40 GB but a live Linux USB
  stick got 15 GB (`free -h`), and the memory map the firmware handed over ended near 17 GB (`grep "System RAM" /proc/iomem`).
- Each stick works alone, in each slot tried. The fault is the 8 GB stick sharing a channel with a 16 GB stick: the board then drops
  that whole channel. With only that pair installed the machine did not start at all.
- After such a failure the board kept giving only 16 GB even with the 8 GB stick removed, until CMOS was cleared. "Load Optimized
  Defaults" did not clear it. The BIOS update on its own did not fix it either; whether it was needed is not known.
- Under a full load on every core the CPU reached 91 °C. The thermal paste is the original. The cooler would not come off: with all
  four screws released, the dried paste still held it to the CPU, and the owner stopped so as not to pull the CPU out of its socket.

## Snapshot / backup taken

None. The host was shut down for the whole of the work, and nothing on its disks was written: Memtest86+ and the live Linux ran from a
USB stick. The BIOS flash and the CMOS clears cannot be undone by a backup; the settings they reset are listed in
`systems/xcp-ng.md` so they can be set again.

## How it was verified

- Memtest86+ 9.00 on the final layout: 40 GB shown, about 24 GB/s, one full pass with no errors (owner, at the console).
- Before the 8 GB stick went back in, the two 16 GB sticks on one channel each: 31.9 GB, 25.3 GB/s, one full pass with no errors.
- For comparison, the day started at 32 GB with both 16 GB sticks on one channel, about 16.5 GB/s.
- XCP-ng started on the new layout afterwards (owner, same evening).

## Still open

- The memory total has not been read from XCP-ng itself: `xl info | grep total_memory` (**UNTESTED**) should show about 40900.
- Replace the thermal paste, then turn Core Performance Boost back on and put the CPU fan back on its normal curve.
- Newer BIOS releases than the one flashed exist; they were not applied.
- Why the 8 GB stick cannot share a channel with a 16 GB stick is not known. The sticks differ in size, rated speed and chip type.
