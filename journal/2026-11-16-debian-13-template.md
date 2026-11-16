# 2026-11-16 — Debian 13 VM template added to Xen Orchestra, and boot-tested

**Who:** Claude Code, at the owner's request  **Scope:** Xen Orchestra; storage `Local storage` and `Nvme`  **Mode:** write
**Task:** one Debian 13 cloud-init template for every home VM built from code (`plans/home-overhaul.md`, "One operating
system")  **Skill:** none

## What changed

- New disk `debian-13-generic-amd64-20261111-2659` (3.2 GB) on `Local storage`: Debian's raw generic cloud image,
  build `20261111-2659`, imported by Xen Orchestra straight from `cloud.debian.org` (JSON-RPC `disk.import` with a URL;
  took 11 minutes). The qcow2 file was refused: URL imports take only VHD or raw.
- New template `debian-13-cloud-20261111-2659`: a VM created from Xen Orchestra's built-in `Debian Trixie 13`
  template (UEFI) with no disk and no network card, the image attached as its boot disk, then converted to a template
  without being booted.
- `Local storage` has about 30 GB free afterwards (REST API, after a rescan).
- The steps are in `iac/templates/debian-13.sh` for the next build.

## Snapshot / backup taken

None: nothing that existed was changed; the template and its disk are new.

## How it was verified

- Checksum: the raw file streamed through `sha512sum` on the workstation matched Debian's `SHA512SUMS` (no signature file
  is published next to it).
- Disk: after a storage rescan the disk shows 3.23 GB used. Before the rescan it showed 9 KB, a stale figure.
- Boot test: a throwaway VM `boottest-delete-me` cloned onto `Nvme` with a 10 GB disk, DHCP and a temporary SSH key
  booted with Secure Boot on and took `10.22.33.19` from the new DHCP pool. Over SSH: Debian 13, kernel
  6.12.116+deb13-amd64, `cloud-init status --long` `done` with no errors, hostname from the config, root filesystem
  grown to 9.7 GB, 265 MB of memory used just after first boot (1 GB VM). The VM was deleted with its two disks (both
  answered 404 afterwards); the template's disk was not attached to it and is still there.

## Still open

- `iac/templates/debian-13.sh` as a whole is untested; only its "already exists" guard ran.
- No Xen guest agent in the image, so Xen Orchestra shows no IP address for clones; Ansible installs it later.
