# OpenBao stores its data with Raft on the VPS's disk

Decided: 2026-10-26 (owner, in a working session; written up by an agent for
review). Status: proposed — in force once the owner approves.

## Why

Raft ("integrated storage") is built into OpenBao, so there is no second
database to run, patch and back up next to it. It has its own snapshot
command, which gives a consistent backup of a running server. The alternative,
PostgreSQL, would add a database whose loss takes every secret with it.

## Cost / what this rules out

- A single node: no high availability. If the VPS is down, OpenBao is down
  (`decisions/foundations-on-vps.md` already accepts this).
- Backups must be Raft snapshots taken through OpenBao, not a copy of the
  volume while it runs. Taking a snapshot needs a token with permission for
  it, which has to be set up and kept away from agents that could delete the
  backups (`decisions/agent-access.md`).

## Where it lives

`systems/openbao.md`, `apps/vps/openbao/`.
