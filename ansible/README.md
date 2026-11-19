# Ansible — after a machine boots

OpenTofu creates a machine (`iac/`), cloud-init gets it onto the tailnet once at first
boot, and Ansible configures everything inside it from then on. Pigsty is separate: it
has its own playbooks and `pigsty.yml`, and runs after `base.yml`
(`agents/plans/shared-postgres.md`).

**Status:** `base.yml` ran against `pigsty-1` on 2026-11-06. A second run changed
nothing, and its firewall rule survived a reboot.

## Playbooks

- `base.yml` — Oracle Cloud machines (group `oci`): opens Tailscale's port in the
  image's own firewall and removes unused packages.
- `oob.yml` — the out-of-band Raspberry Pi (group `oob`, `systems/oob.md`). First ran
  on 2026-11-14; a second run changed nothing, and its settings survived a power cycle.
  The Pi is not a tailnet machine of the main account, so it is reached by its LAN
  address, from outside through the router's subnet route.

- `common.yml` — every host: `htop` and `btop`. Ran on `xo-ce` and `cache-1` on
  2026-11-16; a second run changed nothing. Not yet run on `pigsty-1` or `oob-1`. It
  refreshes apt's package lists even under `--check`, because a dry run on a fresh VM
  that never fetched them fails with "No package matching 'htop'" (seen on `cache-1`).
- `xcpng.yml` — VMs on the XCP-ng host (group `xcpng`): the management agent
  `xe-guest-utilities`, a release `.deb` pinned by its SHA-256, so the host sees each VM's
  addresses and memory and Xen Orchestra can shut it down cleanly. Ran on `xo-ce` on
  2026-11-16 (7.11.0 to 10.0.0; Xen Orchestra then reported agent 10.0.0-1 and the VM's
  addresses); a second run changed nothing. Also ran on `cache-1` right after it was
  built (2026-11-16); Xen Orchestra then reported agent 10.0.0-1 and its address.
  It also installs a native systemd unit for the agent (upstream's, with Debian's
  paths), because the `.deb` ships only a SysV script that systemd warns it will
  stop supporting; on both VMs the warning stopped and the agent kept reporting.
- `cache.yml` — `cache-1` only: Docker from Debian, then Artifact Keeper from
  `apps/homeserver/artifact-keeper/` with its secrets from OpenBao
  (`kv/homelab/artifact-keeper`). First ran on 2026-11-16
  (`agents/journal/2026-11-16-deploy-artifact-keeper.md`).
- `cache-client.yml` — group `lan_cache_clients`: apt's Debian mirrors and Docker's
  registry mirror pointed at cache-1, with Debian's own mirror and Docker Hub as the
  fallback when it is down; `lan_cache: ""` switches a host back to the internet. First
  ran on `proxy-1` on 2026-11-18: `apt update` then fetched its lists from cache-1, a
  `docker pull` went through the mirror (cache-1's log), and a second run changed nothing.
- `proxy.yml` — `proxy-1` only: Docker from Debian, then Traefik from
  `apps/homeserver/traefik/` with the Cloudflare token and the zone from OpenBao
  (`kv/general/cloudflare`). First ran on 2026-11-18
  (`agents/journal/2026-11-18-build-proxy-1-traefik.md`).

## Adding a host

For a home VM built from code, in this order and in the same change that builds it:

1. `iac/<name>-vm.tf`, `./run.sh plan`, the owner reads it, `./run.sh apply`
   (`iac/README.md`).
2. Add the host to `inventory.yml` under `xcpng` **and** to `lan_cache_clients`. Only a
   host that must not use the cache goes in `lan_cache_exempt` instead, with the reason
   as a comment.
3. `ansible-playbook common.yml xcpng.yml cache-client.yml -l <name>`.
4. Then the host's own playbook. Its packages and images now come through cache-1; an
   upstream the cache does not have yet is added first (`agents/skills/add-a-cache-remote/`).

**The LAN cache rule** (owner; `apps/README.md`, `agents/plans/home-overhaul.md` step B00):
every home VM downloads through cache-1, so a package or image leaves home once.
`.githooks/check-cache-clients.py` enforces step 2: the pre-commit hook and CI fail when
a host in `xcpng` is in neither group (`mise run check:cache-clients`). Added on
2026-11-18, after `proxy-1` was built pulling straight from the internet.

## Use

Run from this folder on a machine on the tailnet. `mise install` provides Ansible.

```bash
ansible-playbook base.yml --check --diff   # read this first
ansible-playbook base.yml
```

## Pigsty

`pigsty/pigsty.yml.template` is the config on `pigsty-1` with its secrets and address
replaced by placeholders. `pigsty/render.sh` fills it from `kv/general/pigsty` and writes it
to the node, and applies `pigsty/patch-node.sh` and the alert receiver, for what Pigsty has no
setting for. `--check` compares `pigsty.yml` without changing anything; it passed on 2026-11-06.
A full rebuild from it is **UNTESTED**. Change the template, not the file on the node, then run the
Pigsty playbook for that part. Changing a password means updating OpenBao, rendering and
running the playbook; that was done once, for HAProxy's, with
`./node.yml -l all -t haproxy_config,haproxy_reload`.

## Rules

- The inventory names tailnet machines by short name only, so the tailnet's name and
  addresses stay out of this public repo. LAN machines use their LAN address
  (`inventory/network.md`).
- No secrets in this folder. Anything secret is read from OpenBao when it runs.
- Private SSH keys stay on the machine that runs this; the public keys the
  playbooks install are in `files/`. `~/.ssh/pigsty` exists only on the
  owner's workstation (created 2026-11-06, no passphrase, no copy).
- CI checks only the LAN cache rule in `inventory.yml` (above); it does not run or lint
  the playbooks.
