# VPS

A small rented server outside the home network that runs the lab's
always-on, shared and overflow services, deployed with Dokploy.

**Status:** running. Step 0 of `plans/vps-foundations.md` documented it on
2026-10-26 (`journal/2026-10-26-recon-vps.md`). Rows: `inventory/hosts.md`,
`inventory/services.md`.

## What goes here

What must stay up when home is down, what other people use, overflow, and
quick deploys — the rule and its reasons are `decisions/vps-role.md`. The
foundation services (OpenBao, SSO) also live here
(`decisions/foundations-on-vps.md`).

## How it works

Read on 2026-10-26 over SSH and through Dokploy, unless it says otherwise
(`journal/2026-10-26-recon-vps.md`). Security details of the firewall and
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
  version-specific feature. Versions are not recorded in this public repo.
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

## Rules

- Nothing admin-facing on a public port except the Dokploy dashboard, which
  is public by the owner's choice. OpenBao and SSH are tailnet-only.
- No real domain, public IP or tailnet name in this repo — the commit hook
  blocks domains on the local list, public IPs and tailnet names
  (`repo/secret-scanning.md`); use placeholders.
- Security findings (exposed ports, missing authentication) do not go in this
  repo while they are unfixed.

## Open questions

See [`decisions/open-questions.md`](../decisions/open-questions.md),
sections "Remote VPS (Dokploy)" and "Foundations".
