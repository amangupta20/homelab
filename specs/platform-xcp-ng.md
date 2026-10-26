---
id: platform-xcp-ng
type: module-design
title: platform — XCP-ng and Xen Orchestra
status: draft
parent: arch-homelab
---

# platform

**Responsibility.** Keep the layer everything else sits on boring: the
hypervisor, its management UI, and the snapshot discipline that has already
destroyed VMs once.

**Owns.** The hypervisor pool, Xen Orchestra, and the snapshot rule
(`platforms/xcp-ng-xen-orchestra.md`).

**Boundary.** No other module deletes or merges snapshots. Modules may ask Xen
Orchestra to take one; none may touch the disk chain by hand.

## The rule that has already cost two days

Never delete a base snapshot by hand — it can be a link in the live disk chain.
Merge or delete only through the Xen Orchestra web UI, with a verified backup
first. In July 2026 manual handling destroyed VMs and cost about two days.

## Shape (probably)

- Scheduled snapshots plus delta backups for plain VMs, to TrueNAS then offsite.
- Xen Orchestra's own config and pool metadata backed up daily, ten copies kept,
  result posted to ntfy.
- Stateful apps get an app-level backup on top; an image alone is not enough.

## Unconfirmed — research needed

- Whether the current schedule and retention are what is actually configured.
  The documents describe an intention; nobody has compared it to the live pool.
- Whether a restore of Xen Orchestra's own config has ever been tried.
