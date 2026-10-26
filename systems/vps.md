# VPS

A small rented server outside the home network that runs the lab's
always-on, shared and overflow services, deployed with Dokploy.

**Status:** running — from the owner, not yet documented beyond this page.
Rows: `inventory/hosts.md`, `inventory/services.md` (Dokploy).

## What goes here

What must stay up when home is down, what other people use, overflow, and
quick deploys — the rule and its reasons are `decisions/vps-role.md`. The
foundation services (OpenBao, SSO) also live here
(`decisions/foundations-on-vps.md`).

## How it works

- **Dokploy** deploys every app on the VPS. App definitions move into this
  repo under `apps/vps/<app>/`; how to deploy one is
  `skills/deploy-on-dokploy/`.
- **Tailscale** joins the VPS and the homelab. Admin access and anything
  internal (OpenBao) is reachable only over the tailnet.
- **Public traffic** reaches public apps through Cloudflare. Whether Dokploy's
  own proxy or something else terminates it is not documented yet.
- **Backups** go to Garage on TrueNAS at home (`systems/backups.md`).

## Rules

- Nothing admin-facing on a public port: Dokploy's UI, OpenBao and SSH are
  tailnet-only.
- No real domain or public IP in this repo — the commit hook blocks them
  (`repo/secret-scanning.md`); use placeholders.

## Open questions

`decisions/open-questions.md`, "Remote VPS (Dokploy)".
