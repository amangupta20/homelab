# XCP-ng host — notes

How the facts on `lab/systems/xcp-ng.md`, "Hardware", were found, and the tests
behind them. Read by the owner at the machine on 2026-11-13 (BIOS screens,
Memtest86+ 9.00, a live Linux USB stick), with Claude Code advising
(`agents/journal/2026-11-13-xcp-ng-host-ram-and-bios.md`). XCP-ng was started on
this layout the same evening (owner).

## Slot names

The BIOS and the manual name the slots differently. The manual's order from
the CPU is DDR4_4, DDR4_2, DDR4_3, DDR4_1, with channel A being DDR4_4 and
DDR4_2 ([manual, page 9](https://download.gigabyte.com/FileList/Manual/mb_manual_b450m-ds3h_e_1101.pdf)).
That the BIOS names follow the same physical order is an assumption: it fits
every reading taken, but nobody traced it on the board.

## Memory tests

With the layout on the page, Memtest86+ showed 40 GB usable at about 24 GB/s
and one full pass finished with no errors. The manual only lists two-stick and
four-stick layouts; three sticks is outside what it documents.

- **The 8 GB stick sharing a channel:** tried on 2026-11-13 sharing channel A
  and sharing channel B, each time with one 16 GB stick, with the same result:
  the board dropped both sticks on that channel and the operating system saw
  16 GB.
- **A failed layout sticks.** After the 8 GB stick had been in the wrong
  place, the two 16 GB sticks stayed at 16 GB even with it removed.
  "Load Optimized Defaults" did not fix that; shorting the `CLR_CMOS` pins
  for about 30 seconds did.
- **Lowering the memory speed:** with a manual 2133 MHz and the 8 GB stick
  sharing a channel, the board restarted a couple of times and fell back to
  its automatic setting.

## BIOS menu locations

The System Memory Multiplier location was read off the screen on 2026-11-13.
The SVM Mode and IOMMU locations are from memory; the owner found and enabled
both that day.

## Thermal paste

The thermal paste between CPU and cooler is the original and has dried out.
On 2026-11-13, with every core loaded from a live Linux USB stick, the CPU
reached 91 °C (`sensors`, `k10temp` `Tctl`); its limit is 95 °C (AMD's figure
for this CPU, from memory, unverified). The cooler could not be removed that
day because the dried paste holds it to the CPU.

Core Performance Boost lets the CPU run above its base 3.2 GHz, up to
3.6 GHz, at the cost of more heat. With it off the CPU is slower at peak; how
much, and how many degrees the two settings save, was not measured.
