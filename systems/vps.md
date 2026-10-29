---
type: system
status: "running"
verified: "yes (recon 2026-10-26 over SSH and Dokploy API)"
hosts:
  - Remote VPS
tags:
  - system
  - vps
  - dokploy
  - oci
---

# VPS

A small rented server outside the home network that runs the lab's
always-on, shared and overflow services, deployed with Dokploy.

**Status:** running. Step 0 of `plans/vps-foundations.md` documented it on
2026-10-26 with a read-only recon. Rows: `inventory/hosts.md`,
`inventory/services.md`.

## What goes here

What must stay up when home is down, what other people use, overflow, and
quick deploys — the rule and its reasons are `decisions/vps-role.md`. The
foundation services (OpenBao, SSO) also live here
(`decisions/foundations-on-vps.md`).

## How it works

Read on 2026-10-26 over SSH (`uname`, `/etc/os-release`, `free`, `df`,
`swapon --show`, `docker info`, `docker service ls`, `docker ps -a`, the OCI
instance metadata service) and through Dokploy's API, unless it says
otherwise. Security details of the firewall and
access setup are kept out of this public repo on purpose.

- **Machine:** Oracle Cloud Infrastructure (OCI), shape `VM.Standard.A1.Flex`
  (Ampere, ARM64), from the instance metadata service. 4 CPUs, 23 GiB RAM,
  193 GB disk (68% used), an 8 GB swap file. Ubuntu 24.04.4 LTS. Every image
  deployed here must exist for `arm64`. The owner runs it on the Always Free
  tier and has no plan to rebuild it (owner, 2026-10-26).
- **Admin access:** SSH with a key, over Tailscale (Tailscale 1.102.3).
- **Docker** 29.7.2 in swarm mode (single node), as Dokploy installs it.
- **Dokploy**, with its own Postgres and Redis (`docker service ls`). The
  owner applies every Dokploy update when the UI offers it (owner,
  2026-10-26), so check the running version before relying on a
  version-specific feature. The Dokploy and Traefik versions are not recorded
  in this public repo.
- **Public traffic** enters through Dokploy's Traefik (container
  `dokploy-traefik`) on ports 80 and 443; each app's domain is set in Dokploy.
  The Dokploy dashboard is also on a public domain, by the owner's choice
  (owner, 2026-10-26).
- **How apps are defined:** each Dokploy app is a Compose service. Most store
  their Compose file inside Dokploy (source type `raw`); a few pull it from
  GitHub repositories, none of them this one. Dokploy checks each app out at
  `/etc/dokploy/compose/<appName>/code`. Moving them into `apps/vps/` is step
  5 of the foundations plan.
- **Agents will reach Dokploy** through Dokploy's API, each with its own API
  key — not set up yet. The shared Dokploy MCP server that used to run here
  was removed on 2026-10-26 (`journal/2026-10-26-remove-dokploy-mcp.md`).
- **Backups** go to Garage at home through a Dokploy destination
  (`systems/backups.md`).

## Firewall

Oracle's Ubuntu image keeps its firewall in `/etc/iptables/rules.v4` and
`rules.v6`, which `netfilter-persistent` loads at every boot, before Docker
starts. Docker then adds its own rules in memory on each start. The boot files
must hold only Oracle's rules, Tailscale's chains and rules the owner adds on
purpose — never Docker's.

- **Never run `netfilter-persistent save` or `iptables-save >
  /etc/iptables/rules.v4` on this VPS.** It saves Docker's live rules too;
  Docker does not remove copies it did not create (the stale rule behind the
  2026-10-29 outage survived two months of boots), so they come back at every
  boot and later block whatever container gets their old addresses. This took
  Hindsight down on 2026-10-29
  (`journal/2026-10-29-hindsight-down-stale-firewall-rules.md`).
- To change a rule for good, edit the file by hand, then check it with
  `sudo iptables-restore --test < /etc/iptables/rules.v4`.
- **When a container cannot reach another one on the same network** (the
  connection times out), look for stale rules first. This lists bridges named
  in the firewall that no longer exist; it should print nothing (ran clean
  2026-10-29, after the cleanup):

  ```sh
  for t in raw nat; do sudo iptables -t $t -S | grep -oE 'br-[0-9a-f]{12}'; done | sort -u |
    while read b; do ip link show "$b" >/dev/null 2>&1 || echo "stale: $b"; done
  ```

## Rules

> [!IMPORTANT]
> - Nothing admin-facing on a public port except the Dokploy dashboard, which
>   is public by the owner's choice. OpenBao and SSH are tailnet-only.
> - No real domain, public IP or tailnet name in this repo — the commit hook
>   blocks domains on the local list, public IPs and tailnet names
>   (`repo/secret-scanning.md`); use placeholders.
> - Security findings (exposed ports, missing authentication) do not go in this
>   repo while they are unfixed.

## Open questions

See [`decisions/open-questions.md`](../decisions/open-questions.md),
sections "Remote VPS (Dokploy)", "Secrets (OpenBao)" and "Foundations".
