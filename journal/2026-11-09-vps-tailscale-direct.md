# 2026-11-09 — opened Tailscale's port in the VPS's Oracle security list

**Who:** the owner, with Claude Code  **Scope:** Remote VPS, Oracle security list of its subnet  **Mode:** write
**Task:** find out why peers reached the VPS through a Tailscale relay (seen in the 2026-11-07 handoff)  **Skill:** none

## What changed

The owner added one ingress rule to the security list of the VPS's subnet in the Oracle console: stateful, source
`0.0.0.0/0`, UDP, destination port 41641, "Tailscale direct connections". No restart.

## Snapshot / backup taken

None: one firewall rule that only opens the port Tailscale already listens on.

## What was found

- Only paths *to* the VPS were relayed: the workstation and the VPS pinged each other through Tailscale's Mumbai relay
  ("direct connection not established"), while the VPS reached `pigsty-1` directly in 1 ms, and the workstation
  reached `pigsty-1` directly too.
- Not the host firewall: Tailscale's `ts-input` chain accepts UDP 41641 ahead of Oracle's image `REJECT`, and its
  counter showed traffic arriving. Not the NAT: `tailscale netcheck` reported `MappingVariesByDestIP: false` on the
  workstation and both VPSes, and `pigsty-1`'s network map listed the VPS's public endpoint.
- The test that decided it: 2000 UDP packets from the workstation to port 41641. On `pigsty-1` (whose security list
  allows UDP 41641, `iac/oci/network.tf`) the rule's counter rose by 1998; on the VPS by 0. The VPS's security list
  allowed only ICMP and TCP 80 and 443.
- Why it was direct before 2026-11-07 is not known.

## How it was verified

After the rule: the same 2000 packets raised the VPS's counter by 1922, `tailscale ping dockploy` from the workstation
answered over the VPS's public address in 10 ms, and `tailscale status` shows `direct`.

## Still open

- The VPS's Oracle network is not in OpenTofu, so this rule lives only in the console.
