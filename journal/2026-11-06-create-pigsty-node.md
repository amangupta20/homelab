# 2026-11-06 — created the Pigsty node on Oracle Cloud

**Who:** the owner, with Claude Code  **Scope:** new VPS `pigsty-1`, its network  **Mode:** write
**Task:** the second VPS for phase 1 of `plans/shared-postgres.md`  **Skill:** none

## What changed

- OpenTofu (`iac/oci/`) created a network, subnet, internet gateway, route table,
  security list and the instance: 3 OCPUs, 18 GB, 150 GB boot volume at the default
  10 VPUs. `Plan: 6 to add, 0 to change, 0 to destroy`.
- One inbound port is open in Oracle's firewall: UDP 41641, for Tailscale.
- Ansible (`ansible/base.yml`) added that port to the machine's own firewall, in
  `/etc/iptables/rules.v4` and live.
- Pigsty is not installed.
- New: `~/.ssh/pigsty` on the owner's workstation, and `kv/general/tailscale-oci`.

## Snapshot / backup taken

None: a new machine with no data. The Remote VPS was not touched.

## How it was verified

- A second `./run.sh plan` reported "No changes".
- Over SSH on the tailnet: `aarch64`, Ubuntu 24.04.5, 3 CPUs, 17 GiB shown, 145 GB
  disk, `cloud-init status: done`.
- `ansible-playbook base.yml` changed nothing on its second run or after a reboot. After
  the reboot `iptables -S INPUT` still showed the rule before `REJECT`, and
  `iptables-restore --test` passed on the file.
- `tailscale ping` from the owner's workstation answered directly on port 41641, in
  about 10 ms, both before and after the rule. It connected before the rule too, so
  this does not prove the port is what home will use.
- Oracle's API shows the boot volume tagged `orcl-cloud.free-tier-retained = true`. The
  instance has no such tag.

## Still open

- Home to this node has not been tested, because home is down. That is the check the
  port exists for.
- Tailscale key expires 2027-05-05: the node joined untagged.
- Cost Analysis has not been read since the instance started.
- `~/.ssh/pigsty` has no passphrase and no second copy.

## Follow-up

Later on 2026-11-06: the owner's workstation is at home, so the `tailscale ping` above
was already home to this node, and "Home to this node has not been tested" is wrong.
It was direct while the machine's own firewall still rejected new inbound traffic, so
it came through hole punching and does not show the port is needed. The owner chose to
keep the port and rule anyway. The home lab itself is what is down.
