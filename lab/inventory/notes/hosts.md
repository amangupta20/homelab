# Hosts — notes

When and how the rows of `lab/inventory/hosts.md` were checked. The State cells there say how;
linked journal entries hold the detail.

## When each check ran

- Home VMs, TrueNAS and the stopped VMs: the read-only recon of 2026-11-14,
  through the Xen Orchestra, TrueNAS and Portainer APIs and SSH.
- XCP-ng host hardware, read by the owner at the console: 2026-11-13
  (`agents/journal/2026-11-13-xcp-ng-host-ram-and-bios.md`).
- Home router, over SSH: 2026-11-13 (`agents/journal/2026-11-13-openwrt-home-router.md`).
- oob-1: 2026-11-14, after its rebuild. Remote VPS: recon of 2026-10-26.
  pigsty-1: 2026-11-06, the day Pigsty was installed.
- cache-1: 2026-11-16. proxy-1: 2026-11-18. Both in the linked journal entries.
