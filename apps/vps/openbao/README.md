# OpenBao on the VPS

How OpenBao works and the rules around it: `systems/openbao.md`. This page is
only about this stack.

**Status:** running on the VPS since 2026-10-26, unsealed; backup and restore
tested 2026-10-29 from Garage (`journal/2026-10-29-restore-test-openbao.md`) and
2026-10-31 from Backblaze B2 (`journal/2026-10-31-restore-test-openbao-b2.md`).

## Derived from

Where this definition came from, so an upgrade can compare against the same
sources instead of starting over.

| Source | Version read | What was taken |
|---|---|---|
| Dokploy template `blueprints/vault` (github.com/Dokploy/templates) | commit `084d1cb15ff8` (last change to that folder), read 2026-10-26 | nothing: it runs HashiCorp Vault in dev mode (in memory, root token in the environment) behind a public domain |
| lego (github.com/go-acme/lego) | release `v5.5.2`, the latest on 2026-10-26, with an `arm64` image | DNS-01 through Cloudflare (`CF_DNS_API_TOKEN`), v5's `lego run` that both creates and renews, EC256 keys by default |
| OpenBao `Dockerfile` and `.release/docker/docker-entrypoint.sh` (github.com/openbao/openbao) | tag `v2.7.1` | image name, `/openbao/{config,file,logs}` folders, the `openbao` user, and that the default command is a dev server |
| `docker manifest inspect openbao/openbao:2.7.1` | 2026-10-26 | the image is published for `linux/arm64`, which the VPS needs |
| openbao.org docs: install, Raft storage, TCP listener | 2026-10-26 | Raft `path` and `node_id`, required `cluster_addr`, TLS listener settings, no swap |

OpenBao ships no Compose file of its own.

Choices that differ from those sources, and why:

- Real server with Raft storage, not dev mode (`systems/openbao.md`).
- Port bound to the tailnet address only, no Dokploy domain
  (`decisions/foundations-on-vps.md`).
- The config lives inside `compose.yaml` (`configs.content`), so the stack
  does not depend on how Dokploy lays out the git checkout.
- TLS 1.3 only: every client is ours.

## TLS

OpenBao serves a Let's Encrypt certificate for a name under the lab's domain
(`<bao domain>`, kept out of this repo). Its public DNS record points at the
VPS's tailnet IP and is not proxied, so the name only leads anywhere from the
tailnet. Clients trust the certificate with no extra file, and `BAO_ADDR` is
`https://<bao domain>:8200`.

The certificate comes from a DNS-01 challenge: `host/openbao-cert` runs the
pinned `goacme/lego:v5.5.2` image with a Cloudflare token, so Let's Encrypt
never has to reach the VPS. The script installs the result in
`/etc/openbao/tls` (`tls.crt`, and `tls.key` owned by user ID 100, the
container's `openbao` user — `id` inside the image — and readable by nobody
else) and sends OpenBao a SIGHUP, which reloads the certificate without a
restart, so no reseal. `host/openbao-cert.timer` runs it daily; lego renews
when the certificate is close to expiry.

Not in this repo, on the VPS only:

- `/etc/openbao/cert.conf` — `BAO_DOMAIN=<bao domain>`, and
  `LEGO_DNS_RESOLVERS=<public resolver ip>:53` (the first certificate used
  Cloudflare's public resolver; the address is kept out because the scan
  blocks public IPs)
- `/etc/openbao/cloudflare.env` — `CF_DNS_API_TOKEN=<token>`, a Cloudflare
  API token with Zone → DNS → Edit on that one zone, mode 600, root only
- `/etc/openbao/lego/` — lego's account and certificate store
- `/etc/openbao/selfsigned/` — the self-signed certificate used before
  (ECDSA P-256, for the tailnet IP), kept as a fallback

Set up on the VPS — the steps the owner ran on 2026-10-26, in the order a
rebuild needs them. Before: a `DNS only` (not proxied) `A` record for
`<bao domain>` pointing at the VPS's tailnet IP, and a Cloudflare API token
with Zone → DNS → Edit on that one zone.

```bash
sudo install -m 755 host/openbao-cert /usr/local/sbin/openbao-cert
sudo install -m 644 host/openbao-cert.service host/openbao-cert.timer /etc/systemd/system/
sudo install -m 600 /dev/null /etc/openbao/cloudflare.env
sudoedit /etc/openbao/cloudflare.env     # one line: CF_DNS_API_TOKEN=<token>
printf 'BAO_DOMAIN=%s\nLEGO_DNS_RESOLVERS=%s\n' '<bao domain>' '<public resolver ip>:53' \
  | sudo tee /etc/openbao/cert.conf
sudo systemctl daemon-reload
sudo openbao-cert --no-random-sleep      # first certificate
sudo systemctl enable --now openbao-cert.timer
```

Checked from a workstation on 2026-10-26: OpenBao presented a Let's Encrypt
certificate for the name, `curl` with the system trust store got 200 from
`/v1/sys/health`, and OpenBao stayed unsealed through the reload.

## Deploying in Dokploy

Follows `skills/deploy-on-dokploy/` steps 6 and 7, with these differences:

- **No domain.** A Dokploy domain would route OpenBao through the public
  Traefik.
- **Auto-deploy off.** Every restart comes back sealed (seen in the local
  test), and there is no auto-unseal, so a deploy on every push to `main`
  would lock every secret until someone unseals it.
- Environment: only `TAILSCALE_IP` (`.env.example`).

## Data and backups

- `openbao-data` holds the Raft data; `openbao-logs` holds the audit log,
  `/openbao/logs/audit.log`, declared in the config (tested locally 2026-10-27).
- Backup details, schedule, retention and the restore tests are owned by
  `systems/backups.md`, `journal/2026-10-29-restore-test-openbao.md` (Garage), and
  `journal/2026-10-31-restore-test-openbao-b2.md` (Backblaze B2).

## Host scripts

- `host/dokploy-schedule-snapshot.sh`: automated Raft snapshot backup and
  token renewal.
  - Configured in Dokploy Scheduled Tasks as task `openbao-raft-snapshot`
    (type `dokploy-server`, command `bash ./script.sh`). Schedule, destinations,
    retention, and restore tests are owned by `systems/backups.md`.
  - Reads `/etc/dokploy/snapshot.env` on the VPS host (mode 600, root only).
  - Writes the snapshot to a private `/etc/dokploy/backups/openbao` folder
    (mode 700), mounts only that directory read-only into an ephemeral
    `amazon/aws-cli` container to upload to Garage S3 (Tier 1) and Backblaze B2
    (Tier 2), and cleans it up on exit.
  - Verified live 2026-10-31: Raft snapshot streaming, Garage timeout fallback
    (with homelab offline), and Backblaze B2 upload were verified live
    (`journal/2026-10-31-restore-test-openbao-b2.md`). Earlier tests on
    2026-10-29 verified Garage-only upload before moving from `/tmp/openbao-backup`,
    and the owner tested the `/etc/dokploy` path on 2026-10-30.

## Tested

2026-10-26, on a workstation with rootless Podman (not on the VPS): the
`configs.content` block rendered by `docker compose config` with
`TAILSCALE_IP=127.0.0.1`, mounted into `openbao/openbao:2.7.1` with a
throwaway self-signed certificate. `bao status` showed Raft storage, not
initialised. After `operator init` and `unseal` it wrote a kv-v2 secret, took
a Raft snapshot, came back sealed after a restart, and read the secret again
after unsealing. The server logged `unknown or unsupported field
disable_mlock`, so that setting was removed. Dokploy-specific behaviour is
untested.
