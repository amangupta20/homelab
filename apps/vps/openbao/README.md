# OpenBao on the VPS

How OpenBao works and the rules around it: `systems/openbao.md`. This page is
only about this stack.

**Status:** not deployed. The stack was started once locally (see "Tested").

## Derived from

Where this definition came from, so an upgrade can compare against the same
sources instead of starting over.

| Source | Version read | What was taken |
|---|---|---|
| Dokploy template `blueprints/vault` (github.com/Dokploy/templates) | commit `084d1cb15ff8` (last change to that folder), read 2026-10-26 | nothing: it runs HashiCorp Vault in dev mode (in memory, root token in the environment) behind a public domain |
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

The certificate and key live on the VPS in `${BAO_TLS_DIR}`
(`/etc/openbao/tls` by default), as `tls.crt` and `tls.key`, readable by the
container's `openbao` user. They are not in this repo or in Dokploy. A
self-signed certificate is fine (`systems/openbao.md`); clients pin it with
`BAO_CACERT`. **UNTESTED** on the VPS — run it there as `ubuntu`:

```bash
sudo mkdir -p /etc/openbao/tls && cd /etc/openbao/tls
sudo openssl req -x509 -newkey ed25519 -nodes -days 3650 \
  -subj "/CN=openbao" -addext "subjectAltName=IP:<VPS tailnet IP>" \
  -keyout tls.key -out tls.crt
sudo chown 100:root tls.key && sudo chmod 400 tls.key && sudo chmod 644 tls.crt
```

The container runs as user ID 100 (`id` inside `openbao/openbao:2.7.1`), so
the key is owned by that ID and readable by nobody else; on the VPS that ID is
a system account that cannot log in (`getent passwd 100`, 2026-10-26). The
local test used the same `openssl` command with `IP:127.0.0.1` and a key
readable by everyone (rootless Podman maps user IDs differently), so the
ownership step itself is untested.

## Deploying in Dokploy

Follows `skills/deploy-on-dokploy/` steps 6 and 7, with these differences:

- **No domain.** A Dokploy domain would route OpenBao through the public
  Traefik.
- **Auto-deploy off.** Every restart comes back sealed (seen in the local
  test), and there is no auto-unseal, so a deploy on every push to `main`
  would lock every secret until someone unseals it.
- Environment: `TAILSCALE_IP` and `BAO_TLS_DIR` from `.env.example`. Neither
  is a secret.

## Data and backups

- `openbao-data` holds the Raft data; `openbao-logs` is for the audit log once
  it is turned on.
- Back up with `bao operator raft snapshot save`, not by copying the volume
  while it runs. The snapshot job, its token and its destination are not set
  up yet — that is part of `plans/vps-foundations.md` step 2.

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
