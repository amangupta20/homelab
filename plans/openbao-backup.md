# OpenBao backup and restore test

**Status:** not started — handoff written 2026-10-27. This is the last gate
of step 2 in `plans/vps-foundations.md`.

**Goal:** a consistent copy of OpenBao's data reaches Garage at home every
night without stopping or resealing OpenBao, and one copy has been restored
and read back.
**Done when:** Garage holds a snapshot from the last 24 hours, and
`journal/` has a restore test in which a secret written before the snapshot
was read back from a throwaway OpenBao unsealed with the real pieces.

## Why a Raft snapshot, not a Dokploy volume backup of the data

OpenBao keeps its data in Raft (`systems/openbao.md`). A Dokploy volume
backup of `openbao-data` has two modes, and neither works:

- **Container stopped during the backup:** consistent, but OpenBao comes
  back sealed after every run and stays locked until the owner enters two
  unseal pieces.
- **Container running:** Raft writes to its database while the files are
  copied, so the copy can be inconsistent, and that only shows at restore.

`bao operator raft snapshot save` asks the running server for a consistent
copy: no stop, no reseal. Dokploy still does the shipping — it backs up a
volume that holds only finished snapshot files, which is safe to copy live.

## Design

```
host timer (daily)                Dokploy volume backup (daily, later)
  docker exec <openbao>             openbao-snapshots  ->  destination "garage"
    bao operator raft snapshot      (container NOT stopped)
    save /openbao/snapshots/...
```

- **Where the snapshot runs:** a systemd timer on the VPS, the same pattern
  as the certificate renewal (`apps/vps/openbao/host/openbao-cert`). It
  `docker exec`s the `bao` CLI that is already inside the OpenBao container,
  so nothing new is installed. A Dokploy schedule was the other option; it
  was not chosen because whether Dokploy schedules can run a command inside a
  Compose container is unverified, while the host-timer pattern already works
  on this VPS.
- **Inside the container**, `bao` talks to `https://127.0.0.1:8200`. The
  certificate is for the public name, not `127.0.0.1`, so the command sets
  `BAO_TLS_SERVER_NAME=<bao domain>` (read from `/etc/openbao/cert.conf`,
  which already holds `BAO_DOMAIN`). **UNTESTED:** that OpenBao's CLI honours
  `BAO_TLS_SERVER_NAME` like Vault's `VAULT_TLS_SERVER_NAME`. Fallback:
  `-tls-skip-verify` is acceptable here only because the connection never
  leaves the container.
- **Where snapshots land:** a new named volume `openbao-snapshots`, mounted at
  `/openbao/snapshots`. Create the folder in the image's ownership the same
  way `/openbao/file` works — mount it at a path the `openbao` user (uid 100)
  can write, or `docker exec -u 0 ... chown 100 /openbao/snapshots` once after
  the first deploy. Keep a fixed name (`openbao.snap`, overwritten each run,
  written to a temporary name first and renamed) so Dokploy's backup always
  picks up one complete file; Dokploy keeps the history in Garage.
- **Token:** a policy that can only take snapshots, and a periodic token for
  it that each run renews, so it never expires as long as the timer runs:

  ```bash
  bao policy write raft-snapshot - <<'EOF'
  path "sys/storage/raft/snapshot" { capabilities = ["read"] }
  EOF
  bao token create -orphan -policy=raft-snapshot -period=168h \
    -display-name=raft-snapshot -field=token
  ```

  The token goes in `/etc/openbao/snapshot.env` on the VPS
  (`BAO_TOKEN=<token>`, mode 600, root only), created by the owner with
  `sudo install -m 600 /dev/null ...` and `sudoedit`, never typed into an
  agent session. The `default` policy every token carries already allows
  `token/renew-self`. This token can download all of OpenBao's data, but the
  data is encrypted and useless without two unseal pieces; it cannot write,
  delete, or reach Garage. **UNTESTED:** the commands above.
- **Shipping:** in Dokploy, a volume backup of `openbao-snapshots` to the
  existing destination `garage`, with the option to stop the container
  **off**, an hour after the timer, keeping about 14 copies. **UNTESTED:**
  Dokploy's exact option names and the file format it writes (expected: a
  `.tar.gz` of the volume).

## Steps

1. **Compose change** in `apps/vps/openbao/compose.yaml`: add the
   `openbao-snapshots` volume at `/openbao/snapshots`. Merge, redeploy in
   Dokploy (auto-deploy is off), unseal with two pieces. — gate: the volume
   exists, is writable by uid 100, and OpenBao is unsealed.
2. **Policy and token**, by the owner in their own terminal (the token must
   not pass through an agent session; Hindsight saves sessions). — gate:
   `/etc/openbao/snapshot.env` exists, mode 600.
3. **Snapshot script and timer** in `apps/vps/openbao/host/`
   (`openbao-snapshot`, `.service`, `.timer`), modelled on `openbao-cert`:
   source `cert.conf` and `snapshot.env`, find the container by the label
   `com.docker.compose.service=openbao`, renew the token, save to a
   temporary name, rename, log one line. Run once by hand. — gate: a
   non-empty `/openbao/snapshots/openbao.snap` and `bao token lookup` on the
   token shows a renewed TTL.
4. **Dokploy volume backup** to `garage` as above; run it once manually. —
   gate: the file appears in the Garage bucket.
5. **Restore test**, on a workstation: download the newest backup from
   Garage, unpack it, and restore into a throwaway container. The recipe was
   given to the owner on 2026-10-26 and is repeated here, **UNTESTED** with a
   real snapshot:

   ```bash
   mkdir -p /tmp/baorestore && cd /tmp/baorestore   # put openbao.snap here
   openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 1 \
     -subj /CN=t -addext subjectAltName=IP:127.0.0.1 -keyout tls.key -out tls.crt && chmod 644 tls.key
   cat > bao.hcl <<'EOF'
   api_addr = "https://127.0.0.1:8200"
   cluster_addr = "https://127.0.0.1:8201"
   storage "raft" { path = "/openbao/file"  node_id = "vps" }
   listener "tcp" { address = "0.0.0.0:8200" tls_cert_file = "/t/tls.crt" tls_key_file = "/t/tls.key" }
   EOF
   podman run -d --name baorestore -p 127.0.0.1:18200:8200 -v $PWD:/t:ro,Z \
     -v $PWD/bao.hcl:/openbao/config/b.hcl:ro,Z docker.io/openbao/openbao:2.7.1 \
     bao server -config=/openbao/config/b.hcl
   export BAO_ADDR=https://127.0.0.1:18200 BAO_CACERT=$PWD/tls.crt
   bao operator init -key-shares=1 -key-threshold=1     # throwaway keys
   bao operator unseal <throwaway key>
   BAO_TOKEN=<throwaway root> bao operator raft snapshot restore -force openbao.snap
   bao operator unseal; bao operator unseal              # the REAL pieces now
   bao login -method=userpass username=<owner> && bao kv get kv/homelab/test
   podman rm -f baorestore && rm -rf /tmp/baorestore
   ```

   Run it in the owner's terminal, not an agent session: it asks for real
   unseal pieces. — gate: the test secret reads back; journal entry
   `journal/YYYY-MM-DD-restore-test-openbao.md`.
6. **Close out:** `systems/backups.md` (what is backed up, restore tested),
   `systems/openbao.md` "Backups", the inventory row, and step 2 of
   `plans/vps-foundations.md` marked done.

## Not in this plan

- An alert when a snapshot or backup fails (ntfy) — wanted, next.
- A second copy outside home: home is the VPS's offsite copy; home's own
  offsite copy is an open question (`decisions/open-questions.md`, Backups).
- OCI boot-volume backups: the owner was creating a weekly policy kept 20
  days on 2026-10-27 (from the owner; not checked). Check it is attached to
  the boot volume and has run once (`base` was the manual one).

## Links

`systems/openbao.md`, `apps/vps/openbao/README.md`, `systems/backups.md`,
`decisions/agent-access.md` (backups out of agents' reach),
`plans/vps-foundations.md`.
