# Ansible — after a machine boots

OpenTofu creates a machine (`iac/`), cloud-init gets it onto the tailnet once at first
boot, and Ansible configures everything inside it from then on. Pigsty is separate: it
has its own playbooks and `pigsty.yml`, and runs after `base.yml`
(`plans/shared-postgres.md`).

**Status:** `base.yml` ran against `pigsty-1` on 2026-11-06. A second run changed
nothing, and its firewall rule survived a reboot.

## Playbooks

- `base.yml` — Oracle Cloud machines (group `oci`): opens Tailscale's port in the
  image's own firewall and removes unused packages.
- `oob.yml` — the out-of-band Raspberry Pi (group `oob`, `systems/oob.md`). First ran
  on 2026-11-14; a second run changed nothing, and its settings survived a power cycle.
  The Pi is not a tailnet machine of the main account, so it is reached by its LAN
  address, from outside through the router's subnet route.

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
- CI does not check this folder yet.
