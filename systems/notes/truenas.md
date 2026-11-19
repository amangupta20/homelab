# TrueNAS — notes

History and detail behind `systems/truenas.md`.

## Checksum errors on `imp` (2026-11-15, closed 2026-11-16)

The 19:00 replication on 2026-11-15 stopped with `cannot send
'imp/back@auto-2026-11-15_19-00': Input/output error`, and TrueNAS raised a
critical `ReplicationFailed` alert. `zpool status -v imp` (owner, TrueNAS
shell) showed 8 checksum errors on `xvdc1`, no read or write errors, and one
damaged file: a library inside a Python virtual environment
(`back/nextcloud/admin/files/.../.venv/.../libcublasLt.so.12`), live and in
that one snapshot. Reading it back gave `Input/output error`, so the bad block
is on disk.

How it is read, not proved: the file was created at 00:59 on 2026-11-15 during
a bulk rewrite of `back/nextcloud` (93,535 files changed between 00:30 and
02:00, `find -newerct`), the owner's Nextcloud restore. The scrub that ended at
02:08 had started before the file existed, so it never checked it. The disk
surface is clean and the host logged no disk errors, so the likeliest cause is
corruption on the way to the disk (non-ECC RAM, or the link with 4 CRC
errors), not a failing disk.

What was done (owner, 2026-11-15): the damaged virtual environment was
deleted, `auto-2026-11-15_19-00` destroyed, the partial receive on
`Main/repli` discarded (`zfs receive -A`), a fresh snapshot
`auto-2026-11-15_20-00` taken and the replication started by hand.

Checked through the TrueNAS API on 2026-11-16 (`replication`, `pool/snapshot`,
`pool`): the replication finished at 20:04 IST on 2026-11-15 and `Main/repli`
holds `auto-2026-11-15_20-00`. A scrub of `imp` ran from 20:14 to 21:18 IST
that evening and finished with 0 errors; it is the first check of the other
files the restore wrote. The pool is `ONLINE` and healthy, and `xvdc1` now
shows 0 read, write and checksum errors. Still to do at the next shutdown:
reseat or replace the WD's SATA cable and run a memory test on the host, since
the cause was never found.
