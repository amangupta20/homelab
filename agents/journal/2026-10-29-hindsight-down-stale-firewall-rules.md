# 2026-10-29 — Hindsight down: stale Docker rules in the VPS's boot firewall file

**Who:** the owner on the VPS, Claude Code (Opus 5.5) diagnosing from the workstation  **Scope:** remote VPS, firewall files and the Hindsight stack (`hermes` project in Dokploy)  **Mode:** write
**Task:** the owner: Hindsight broke, find out why  **Skill:** none

## What happened

Hindsight's API stopped starting on the morning of 2026-10-29: its database
migrations timed out connecting to its own Postgres container. Postgres was
healthy (`pg_isready` answered, and a connection from inside its own container
to its network address worked); a connection from the API container to the
same address, on the same Docker bridge, timed out.

The cause was a firewall rule nobody had added on purpose. During VPS setup in
August, `sudo apt install -y iptables-persistent && sudo netfilter-persistent
save` (line in the `ubuntu` user's shell history) saved every rule then
loaded — including Docker's — into `/etc/iptables/rules.v4`, which
`netfilter-persistent` restores at every boot. Docker builds its rules in
memory on each start and does not remove copies it did not create: the stale
rule below was still loaded on 2026-10-29, after the Docker restart of the
2026-10-28 upgrade and after every boot since August
(`sudo iptables -t raw -S PREROUTING`, and the same line in `rules.v4`). One of them, in the `raw` table, dropped traffic to
`172.26.0.2` unless it arrived through a bridge that had not existed since
August.

It did nothing for two months, and why it started now is not settled.
Hindsight's network was not recreated: `docker network inspect -f
'{{.Created}}'` dates it before 2026-10-26, and its database already held
`172.26.0.2`. The breakage followed a Docker upgrade (29.7.2 to 29.9.2,
`/var/log/apt/history.log`, 2026-10-28 20:24 UTC). Leading guess, unverified:
traffic between two containers on one bridge only passes through the firewall
when the `br_netfilter` kernel module is active, which it was on 2026-10-29
(`net.bridge.bridge-nf-call-iptables = 1`); if the upgrade is what turned it
on, the stale rule started seeing Hindsight's traffic only then, and dropped
all of it (counter: 93 packets when found). The kernel logs of the boots
before and after the upgrade would confirm or rule this out.

Three other bridges had stale rules of the same kind, waiting for the same
collision; the saved file also restored port forwards to containers that no
longer existed. All are gone now.

## What changed

- Deleted the live stale rule (`iptables -t raw -D PREROUTING …`); the API
  connected and started.
- During the diagnosis, a `netfilter-persistent save` was run by mistake (an
  example from the chat, meant as illustration), overwriting the August file
  before it was backed up; two `INPUT` accept rules it came with were deleted
  again by hand.
- Rebuilt `/etc/iptables/rules.v4` and `rules.v6` without any Docker rule:
  every line naming a Docker chain or a Docker bridge was filtered out, and
  the result was read line by line before install. What is left is Oracle's
  base rules, Tailscale's chains and one rule the owner added on purpose.
- Rebooted the VPS so the live firewall matches the file.
- Earlier, before the cause was found, Hindsight's Compose file in Dokploy was
  changed to reach Postgres by its container name `hindsight-db` and to join
  its project's `default` network. Not needed for the fix; kept.

The rule that prevents a repeat is on `systems/vps.md` ("Firewall").

## Snapshot / backup taken

No snapshot. The change was to two text files, and the reboot was an
ordinary restart: every app keeps its data in Docker volumes on disk, which a
reboot does not touch. Copies of both files as they were before the cleanup
are on the VPS at `/etc/iptables/rules.v4.bak-2026-10-29` and
`rules.v6.bak-2026-10-29`. They hold the 2026-10-29 save, not the August
file, which the mistaken save had already overwritten — so restoring them
brings back a working firewall, stale Docker rules included. Both cleaned files
passed `iptables-restore --test` / `ip6tables-restore --test` before install.

## How it was verified

- From the API container's network namespace,
  `docker run --rm --network container:hindsight-api busybox nc -zv -w3
  172.26.0.2 5432` changed from "Connection timed out" to "open".
- After the reboot, a scan of the `raw` and `nat` tables for bridge names
  with no matching interface printed nothing (command on `systems/vps.md`).
- After the reboot, Hindsight's `/health` answered 200 from the workstation.

## Still open

- Hindsight's Compose file lives only in Dokploy; moving it into
  `apps/vps/` is not done.
- Why the stale rule only started matching after the 2026-10-28 upgrade:
  the `br_netfilter` guess above is not checked yet.
