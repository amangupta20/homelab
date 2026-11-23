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
- The cluster catalog's zone-transfer list also holds the router's address, because
  the VPS node reaches the Pi through the router's subnet route
  (`apps/vps/technitium/NOTES.md`, "What the first join needed").
- The Pi opens connections to the main tailnet's addresses through the router (the
  VPS node), which needed the change below.

## Tailscale's firewall

Changed 2026-11-23 at the owner's request. In its default mode Tailscale hooks its
own rules into the Pi's firewall, and one of them drops anything from
`100.64.0.0/10` that does not arrive on `tailscale0` (`iptables-save`, same day).
That also dropped the replies when the Pi talked to the main tailnet through the
router, so the DNS cluster's VPS node was `Unreachable` from here.

- `ansible/oob.yml` now runs `tailscale set --netfilter-mode=nodivert`: Tailscale
  keeps its chains but no longer jumps to them (`NetfilterMode: 1` in `tailscale
  debug prefs`; `iptables -S INPUT` and the nat table's `POSTROUTING` show no `ts-`
  jump).
- What its rules did, `nftables.conf` already does or now does: input from
  `tailscale0` and on UDP 41641, forwarding from `tailscale0`, established replies,
  and a new `table ip oob_nat` that masquerades traffic from `tailscale0` out of
  `eth0`, the subnet route's address translation. The `100.64.0.0/10` drop is gone;
  the input chain's default drop still refuses new connections except to the ports
  it opens.
- The masquerade rule went in before the mode changed, so the route stayed up. After
  it: the route `Running` and primary, the Pi reaches the VPS's cluster port (200),
  and the cluster lists the VPS `Connected`. The route from a device on the
  out-of-band tailnet: not yet tested (`agents/journal/2026-11-23-dns-two-way-cluster-and-query-logs.md`).
- Before the change: `/root/iptables-before-nodivert-20261123.txt` and
  `/root/nft-before-nodivert-20261123.txt` on the Pi. To undo: `tailscale set
  --netfilter-mode=on` and remove the task.

