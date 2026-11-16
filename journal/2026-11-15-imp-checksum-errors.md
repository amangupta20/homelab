# 2026-11-15 — checksum errors on `imp` stopped the replication

**Who:** the owner, with Claude Code  **Scope:** TrueNAS VM, pools `imp` and `Main`  **Mode:** write
**Task:** find why the 19:00 replication `imp/back` to `Main/repli` failed, fix it, and check the pool  **Skill:** none

## What changed

- The 19:00 replication failed on `cannot send 'imp/back@auto-2026-11-15_19-00': Input/output error`. `zpool status -v imp`
  showed 8 checksum errors on `xvdc1` and one damaged file, a library inside a Python virtual environment under
  `back/nextcloud`. The facts and how they were read are in `systems/truenas.md`, "Checksum errors on `imp`".
- The owner deleted that virtual environment, destroyed `imp/back@auto-2026-11-15_19-00`, discarded the partial receive on
  `Main/repli` (`zfs receive -A`), took `imp/back@auto-2026-11-15_20-00` and started the replication by hand.
- A scrub of `imp` ran afterwards, 20:14 to 21:18 IST.

## Snapshot / backup taken

None before the fix. Only the snapshot holding the damaged file was destroyed; `auto-2026-11-14_19-00` stayed on both
`imp/back` and `Main/repli` (still there on 2026-11-16, TrueNAS API `pool/snapshot`).

## How it was verified

Read through the TrueNAS API on 2026-11-16 (`replication`, `pool/snapshot`, `pool`):

- replication `imp/back- Main`: `FINISHED` at 20:04 IST, last snapshot `imp/back@auto-2026-11-15_20-00`;
- `Main/repli` and `imp/back` both have `auto-2026-11-15_20-00` as their newest automatic snapshot;
- `imp`: scrub `FINISHED` with 0 errors, pool `ONLINE` and healthy, `xvdc1` at 0 read, write and checksum errors.

That closes `plans/home-overhaul.md` step A3.

## Still open

- The cause is not proved. The likeliest reading is corruption on the way to the disk (non-ECC RAM, or the WD's SATA link,
  which shows 4 CRC errors), not the disk surface. At the next shutdown: reseat or replace that cable and run memtest86+ on the
  host.
- Long SMART self-tests on both disks (`plans/home-overhaul.md`, A6).
