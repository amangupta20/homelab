# 2026-10-26 — installed OpenBao on the VPS

**Who:** the owner, with Claude Code (Opus 5.5)  **Scope:** remote VPS, Dokploy service for `apps/vps/openbao/`  **Mode:** write
**Task:** step 2 of `plans/vps-foundations.md`  **Skill:** `skills/deploy-on-dokploy/` (steps 6–7, with the differences in `apps/vps/openbao/README.md`)

## What changed

- Dokploy Compose service created from this repo (`main`,
  `apps/vps/openbao/compose.yaml`), environment `TAILSCALE_IP` only, no
  domain, auto-deploy off. The first deploy failed with "trying to clone a ssh
  repository without a ssh key": the saved repository URL began with a space,
  and Dokploy treats any URL not starting with `http` as SSH. Retyping the URL
  fixed it.
- Initialised with 3 unseal pieces, any 2 of which unseal it. The pieces are
  kept offline, apart from each other; where is not recorded here.
- `kv/` (kv-v2) enabled, an `admin` policy and a `userpass` user for the
  owner created, the initial root token revoked.
- Audit log: `bao audit enable` was refused ("cannot enable audit device via
  API; use declarative, config-based audit device management instead"), so it
  was declared in the config and the stack redeployed.
- TLS: first a self-signed certificate for the tailnet IP, then a Let's
  Encrypt certificate for a name under the lab's domain, from a DNS-01
  challenge, renewed daily by `openbao-cert.timer`
  (`apps/vps/openbao/README.md`, "TLS"). The script and timer were installed
  by the owner; the agent's attempt was refused by its permission check.

## Snapshot / backup taken

OCI boot-volume backup `base`, taken by the owner before the install; it
shows in the OCI console's limits page as 1 of 5 free backups used.

## How it was verified

From the workstation and over SSH:

- the container runs `openbao/openbao:2.7.1` with port 8200 bound to the
  tailnet IP only (`docker ps`);
- `/openbao/logs/audit.log` exists and grows;
- Dokploy's record for the service has auto-deploy off;
- OpenBao presents a Let's Encrypt certificate for its name, and `curl` with
  the system trust store gets 200 from `/v1/sys/health` (active, unsealed),
  also after the certificate reload.

## Still open

- Backup to Garage and a restore test — the plan's gate for step 2. A Raft
  snapshot, not a volume backup: stopping the container for a backup would
  reseal it.
- An OCI boot-volume backup policy (weekly, kept 20 days) was being set up
  by the owner; check it ran.
