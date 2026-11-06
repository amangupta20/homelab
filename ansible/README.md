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

## Rules

- The inventory holds short names only, so the tailnet's name and addresses stay out
  of this public repo.
- No secrets in this folder. Anything secret is read from OpenBao when it runs.
- SSH keys stay on the machine that runs this. `~/.ssh/pigsty` exists only on the
  owner's workstation (created 2026-11-06, no passphrase, no copy).
- CI does not check this folder yet.
