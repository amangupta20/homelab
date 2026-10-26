---
id: backups-restore
type: module-design
title: backups and restore proof
status: draft
parent: arch-homelab
---

# backups

**Responsibility.** Say what must survive, how it is copied, and what counts as
proof that it can come back.

**Owns.** The backup policy and the list of untested restores
(`ops/backup-restore.md`).

**Boundary.** It does not perform the backups — Xen Orchestra and Borg do. It
sets the rule they are judged by.

## Rule

A backup counts when a test restore works. A green job log counts for nothing.

## Shape

- Plain VMs: Xen Orchestra snapshots plus delta backups to TrueNAS, then offsite.
- Xen Orchestra's own config and pool metadata: daily, ten copies, success or
  failure posted to the `xen-orchestra` ntfy topic.
- Stateful apps (Nextcloud): VM image plus an app-level Borg backup from inside.

## Untested today

- TrueNAS wipe-and-reimport.
- Nextcloud full recovery from Borg.
- The pre-migration re-audit.
- OpenTofu state export offsite — planned, not implemented, so the state bucket
  is currently a single copy.

## Unconfirmed — research needed

- Whether OpenBao's Raft snapshot travels the same offsite path or needs its own.
- Where the offsite copy lands, and whether it is encrypted at rest.
