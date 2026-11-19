# 2026-11-16 — xo-ce updated: Debian packages, Xen Orchestra 5.213.0, guest agent 10.0.0

**Who:** Claude Code, at the owner's request  **Scope:** VM `xo-ce` (Xen Orchestra)  **Mode:** write
**Task:** the owner asked for an update of Xen Orchestra before building the first VM from code  **Skill:** none

## What changed

- 105 Debian packages upgraded (`apt-get full-upgrade`), among them kernel 6.12.117 and Node.js 24.22.3.
- Xen Orchestra updated with the installer it was set up with (`/opt/XenOrchestraInstallerUpdater/xo-install.sh
  --update`, branch `master`): `xo-server` 5.203.0 to 5.213.0, build `xen-orchestra-202611161435`. The installer kept the
  three newest older builds; log at `/var/log/xo-update-2026-11-16.log` on the VM.
- Rebooted onto the new kernel, after checking Xen Orchestra had no running task.
- `ansible/common.yml` installed `btop`; `ansible/xcpng.yml` upgraded the guest agent `xe-guest-utilities` from 7.11.0 to
  10.0.0.
- From this workstation the VM is reached as `xo` with the homelab VM key (`kv/general/vm-ssh`).

## Snapshot / backup taken

Xen Orchestra snapshot `xo-ce before update 2026-11-16 (agent)`, taken before any change and listed among the VM's
snapshots afterwards. To be removed through the Xen Orchestra web UI once the update has run well for a few days, never by
hand (`systems/xcp-ng.md`).

## How it was verified

- After the update and again after the reboot: `xo-server` active, the web UI answered on the VM, the REST API answered
  200, and the Debian 13 template was still listed.
- After the reboot: `uname -r` 6.12.117+deb13-amd64, `node --version` v24.22.3.
- Guest agent: `dpkg -l` shows 10.0.0-1 and `xe-linux-distribution` is active; Xen Orchestra's REST API reports agent
  10.0.0-1 and the VM's IPv4 address. Both playbooks changed nothing on a second run.

## Still open

- The root disk is 83% full (5 GB free). Four Xen Orchestra builds are kept; the oldest (2025-09) is probably still the
  target of the `xo-proxy` link. Not cleaned up.
- The snapshot above, once the update has proved itself.
