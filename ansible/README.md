# Ansible — after a machine boots

OpenTofu creates a machine (`iac/`), cloud-init gets it onto the tailnet once at first
boot, and Ansible configures everything inside it from then on. Pigsty is separate: it
has its own playbooks and `pigsty.yml`, and runs after `base.yml`
(`plans/shared-postgres.md`).

**Status:** `base.yml` ran against `pigsty-1` on 2026-11-06. A second run changed
nothing, and its firewall rule survived a reboot.

## Use

Run from this folder on a machine on the tailnet. `mise install` provides Ansible.

```bash
ansible-playbook base.yml --check --diff   # read this first
ansible-playbook base.yml
```

## Pigsty

`pigsty/pigsty.yml.template` is the config on `pigsty-1` with its secrets and address
replaced by placeholders. `pigsty/render.sh` fills it from `kv/general/pigsty` and writes it
to the node. `--check` compares without changing anything; it passed on 2026-11-06. A full
rebuild from it is **UNTESTED**. Change the template, not the file on the node, then run the
Pigsty playbook for that part. Changing a password means updating OpenBao, rendering and
running the playbook; that was done once, for HAProxy's, with
`./node.yml -l all -t haproxy_config,haproxy_reload`.

## Rules

- The inventory holds short names only, so the tailnet's name and addresses stay out
  of this public repo.
- No secrets in this folder. Anything secret is read from OpenBao when it runs.
- SSH keys stay on the machine that runs this. `~/.ssh/pigsty` exists only on the
  owner's workstation (created 2026-11-06, no passphrase, no copy).
- CI does not check this folder yet.
