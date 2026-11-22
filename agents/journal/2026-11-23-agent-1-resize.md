# 2026-11-23 — Resize agent-1 memory and root disk

**Who:** Codex, at the owner's request. **Scope:** `agent-1`. **Mode:** write.
**Task:** Grow the root disk to 150 GB and set the static and dynamic maximums to 10 GiB and 8 GiB. **Skill:** none.

## What changed

- The Xen Orchestra REST API reported a graceful shutdown, a disk resize and a start. The API also set the two memory maximums. The VM had one shutdown window.
- Updated `iac/agent-vm.tf` with the disk size and the dynamic maximum. The provider reads the dynamic maximum and writes both maximums on VM updates, so a later VM update can reset the separately configured static maximum.

## Snapshot / backup taken

Xen Orchestra snapshot `agent-1 before RAM and disk resize 2026-11-23`. The API reported success and listed the snapshot before shutdown.

## How it was verified

- The pre-change OpenTofu plan showed one in-place change covering disk size and dynamic memory. The post-change plan reported no changes.
- Xen Orchestra reported the VM running with the requested memory limits and a 150,000,893,952-byte root disk. Over SSH, `free -m` reported 7,894 MiB total. The boot journal showed `systemd-growfs-root` expanded the ext4 filesystem, and `df -h /` reported 138 GiB total and 86 GiB available.
