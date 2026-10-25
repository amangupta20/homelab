# XCP-ng & Xen Orchestra

XCP-ng is the hypervisor (the layer that runs VMs on bare metal). Xen
Orchestra (XO) is its web UI — start/stop VMs, take snapshots, schedule
backups. This pair is the base everything else sits on.

## How VMs are protected

- Plain VMs: XO takes scheduled snapshots plus delta backups (only changed
  blocks) and sends them to TrueNAS storage, then offsite.
- XO's own config + pool metadata: backed up daily at midnight (`0 0 * * *`),
  keeps 10 copies, success/failure reported to the `xen-orchestra` ntfy topic.
- Apps with state inside them (Nextcloud): image backup is not enough, they
  also get an app-level Borg backup from inside.

## The one rule that destroys VMs

> Never delete an XCP-ng base snapshot by hand. It can be a link in the live
> disk chain. Merge or delete only through the Xen Orchestra web UI, with a
> verified backup first.

What happens if you break it: the VM's disk chain breaks and the VM is
unbootable. This happened in July 2026 — manual snapshot handling destroyed
VMs, TrueNAS backups recovered data but the XO instances were lost (~2 days
of work).

## What reports don't prove

- A green backup job is not a restore. Only a test restore counts as proof.
- Uptime Kuma saying "up" is not restore validation either.
