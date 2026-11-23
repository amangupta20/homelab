# Technitium: notes

Sources, choices and gotchas behind `README.md`. Measured or read on 2026-11-23
unless a line says otherwise.

## Why these choices

- **Technitium, and the lists:** owner, 2026-11-23; the comparison and the memory
  measurements are in `agents/plans/home-overhaul.md`, B4b.
- **Docker rather than the native installer** (owner, 2026-11-23): one image pin
  for the Pi and the VPS, pulled through the LAN cache's Docker Hub remote. The
  native installer fetches .NET from Microsoft, which the cache does not proxy.
- **Host networking:** on Docker's bridge every query arrives from the bridge
  address (seen in a throwaway container on agent-1: every client was
  `172.17.0.1`), which would empty the per-device log.
- **Docker without firewall rules** (`"iptables": false, "ip6tables": false` in
  `/etc/docker/daemon.json`): with them on, Docker sets the forward policy to drop,
  which would break the Pi's subnet route. `daemon.json` is written before Docker is
  installed, so its first start already reads it.

## Settings through the API

The `DNS_SERVER_*` variables in `compose.yaml` are read only on the first start,
when no configuration exists (Technitium's `DockerEnvironmentVariables.md`). So
`ansible/oob.yml` signs in and sets the rest on every run, by `POST` with form
fields: `settings/get` and `settings/set` (`blockListUrls`,
`blockListUpdateIntervalHours`, `forwarders`, `forwarderProtocol`, `recursion`,
`recursionNetworkACL`, `enableBlocking`), `settings/forceUpdateBlockLists` when the
lists changed, `allowed/export`, `allowed/add` and `allowed/delete`, `zones/list`,
`zones/create` and `zones/records/add` with `overwrite`. Each call was tried on a
throwaway 15.6.2 container on agent-1 before the playbook used it. Upstreams are
written as `https://<host>/dns-query (<address>)`, so reaching them needs no lookup.

## Gotchas

- **Memory cap needs the kernel's memory controller.** Raspberry Pi OS ships with it
  off (`/proc/cgroups` had no `memory` row), and Docker then accepts `mem_limit`
  without enforcing it (`docker stats` showed `0B / 0B`). The playbook adds
  `cgroup_enable=memory` to `/boot/firmware/cmdline.txt` and reboots once. A
  container created before that keeps no limit until it is recreated
  (`HostConfig.Memory` was `0`; after `docker compose up -d --force-recreate` it was
  671088640, and `docker stats` showed the 640 MiB cap).
- **The console is the wrong place for list changes:** the next playbook run resets
  the lists, upstreams and allowlist to the repo's.

## Measured on the Pi

All 573,538 blocklist entries loaded: Technitium 335 MB resident, 243 MB anonymous
(`/proc/<pid>/smaps_rollup`); dockerd 87 MB, containerd 22 MB (`ps`). After the
reboot and recreate, `docker stats` showed about 218 MiB of the 640 MiB cap a
minute after start.
