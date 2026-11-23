# oob-1: notes

Details behind `lab/systems/oob.md`.

## DNS resolver

Technitium runs here in Docker (the owner's choice: DNS is the Pi's only other
job, so it carries the home's primary resolver; `agents/plans/home-overhaul.md`,
B4b). What `ansible/oob.yml` adds for it, checked over SSH when it was deployed
(`agents/journal/2026-11-23-technitium-oob-1.md`):

- Firewall: DNS (UDP and TCP 53) and the console (TCP 5380) from the home subnet,
  and the cluster's HTTPS API (TCP 53443) from the router's address only: the VPS
  node reaches the Pi through the router's subnet route, translated to that address.
  The file now replaces only its own table (`table inet filter` /
  `delete table inet filter`) instead of `flush ruleset`, which would delete
  Tailscale's tables on a reload; after the change all seven tables were still
  there (`nft list tables`) and the route stayed primary.
- Docker from Debian through the LAN cache, with Docker's own firewall rules off
  (`/etc/docker/daemon.json`), so `nftables.conf` stays the only firewall.
- `cgroup_enable=memory` in `/boot/firmware/cmdline.txt`, so the container's 640 MB
  cap is enforced (it was not before: `apps/homeserver/technitium/NOTES.md`).
  Previous file kept as `/root/cmdline.txt.bak-20261123`, the previous firewall file
  as `/root/nftables.conf.bak-20261123`.
- The DNS cluster's primary node (`dns.home.arpa`), started by the playbook; the
  `home` zone is in the cluster's catalog, so the VPS node gets a copy.
- After the reboot this needed, Tailscale, the route, the firewall and Technitium
  came back without help (`tailscale status --json`, `nft list tables`, `dig`).

