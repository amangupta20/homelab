# 2026-11-16 — cache-1 built from code: the first home VM made by OpenTofu

**Who:** Claude Code; the owner read the plan and asked for the apply  **Scope:** new VM `cache-1` on the XCP-ng host  **Mode:** write
**Task:** the cache VM of `plans/package-and-image-cache.md`, step B's first VM in `plans/home-overhaul.md`  **Skill:** none

## What changed

- `./run.sh apply` of the saved plan (1 to add) created `cache-1` in 51 s: the Debian 13 template, 2 vCPU, static memory
  128 MiB to 1.5 GiB with dynamic 256 MiB to 1.5 GiB, a 100 GB disk on `Nvme`, UEFI with Secure Boot, power-on with the
  host, tags `managed-by-opentofu` and `cache`. cloud-init set the hostname, the homelab VM key and `10.22.33.137`.
- The wrapper copied the new state to Garage (`xcp-ng/20261116T172306Z.tfstate`).
- `ansible/common.yml` (htop, btop) and `ansible/xcpng.yml` (guest agent 10.0.0) ran on it.
- Two fixes found on the way, both in `iac/cache-vm.tf`:
  - XCP-ng rounded the disk up to whole 2 MiB blocks (100,000,595,968 bytes), so the next plan wanted to shrink it. The
    size is now written as 47,684 blocks of 2 MiB; the plan then showed no changes.
  - The cloud-init drive stayed attached: the provider deletes it only when `power_state = "Running"` is also set. The
    line was added for future VMs, and on `cache-1` the 10 MB drive, unmounted, was deleted through Xen Orchestra
    (`vdi.delete`).

## Snapshot / backup taken

None: a new VM, no existing one changed. By the owner's decision the cache VM has no automatic backups
(`decisions/backup-tiers.md`, rebuildable state).

## How it was verified

- Over SSH as `debian` with the homelab VM key: hostname `cache-1`, `eth0` at `10.22.33.137/24`, default route via
  `10.22.33.1`, `cloud-init status --long` `done` with no errors, Secure Boot enabled, 1,461 MB of memory visible with
  261 MB used, a 92 GB root filesystem with 88 GB free.
- Xen Orchestra's REST API: the memory limits above, agent 10.0.0-1 reporting `10.22.33.137`.
- Both playbooks changed nothing on a second run.
- After both fixes and the drive's removal: `./run.sh plan` printed `No changes.`

## Still open

- The restore test of the `xcp-ng` state's Garage copy, now that the root holds a resource.
- Its DNS lists two IPv6 resolvers advertised by the router besides `10.22.33.1`.
- Artifact Keeper itself: plan steps 2 and 3.
