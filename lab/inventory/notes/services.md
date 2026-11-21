# Services — notes

When and how the rows of `lab/inventory/services.md` were checked. The State cells there say how;
linked journal entries hold the detail.

## When each check ran

- Home services on TrueNAS, the home VMs and Portainer: the read-only recon
  of 2026-11-14, through the Xen Orchestra, TrueNAS and Portainer APIs and SSH.
  Nextcloud AIO went down at 2026-11-13 22:56 UTC, read from its container's
  log in that recon.
- Home network DHCP and DNS: 2026-11-13, over SSH on the router.
- Dokploy and OpenBao's health: the VPS recon of 2026-10-26. Dokploy reading
  OpenBao at deploy time: 2026-10-27. OpenBao's restore test: 2026-10-29.
- Deploys, each checked the same day: the shared Postgres 2026-11-06; Blinko and Sablier deployed 2026-11-07;
  pg-proxy, pgAdmin and CloudBeaver 2026-11-09; Authentik and Langfuse
  2026-11-10, the day the owner first signed in to Langfuse through Authentik
  and sent the probe trace; Artifact Keeper 2026-11-16, its first client
  (`oob-1`) 2026-11-17; Traefik on proxy-1 2026-11-18, the dashboard's
  forward-auth 2026-11-21. Hermes WebUI (second): deployed 2026-10-27,
  updated 2026-11-21.

## State detail

- **Authentik:** both containers healthy, public login 200, admin paths 403
  publicly, admin hostname 403 from the public address; the first app to sign
  in through it was Langfuse, by the owner.
- **Langfuse:** four containers healthy, public health 200 with a Let's Encrypt
  certificate, password sign-up 422 and login 401, Sablier wake 27–35 s; the
  owner's first sign-in worked and a probe trace went in over OpenTelemetry
  (`agents/journal/2026-11-10-deploy-langfuse.md` covers the deploy).
