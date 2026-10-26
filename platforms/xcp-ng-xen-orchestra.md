# XCP-ng & Xen Orchestra

XCP-ng is the hypervisor (the layer that runs VMs on bare metal). Xen
Orchestra (XO) is its web UI — start/stop VMs, take snapshots, schedule
backups. This pair is the base everything else sits on.

How VMs and XO itself are backed up: `ops/backup-restore.md`.

## The one rule that destroys VMs

> Never delete an XCP-ng base snapshot by hand. It can be a link in the live
> disk chain. Merge or delete only through the Xen Orchestra web UI, with a
> verified backup first.

What happens if you break it: the VM's disk chain breaks and the VM is
unbootable. This happened in July 2026 — manual snapshot handling destroyed
VMs, TrueNAS backups recovered data but the XO instances were lost (~2 days
of work).
