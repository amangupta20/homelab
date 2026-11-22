# 2026-11-22 — agent-1: the desktop, the Orca test, and Claude Code's setup

**Who:** Claude Code (Opus 5.5)  **Scope:** `agent-1`, OpenBao (one new secret)  **Mode:** write
**Task:** owner, in session: finish step B0 so Claude Code can move to agent-1 (backups decided later)
**Skill:** none

## What changed

- `ansible/agent.yml`: a TigerVNC and Xfce desktop on display :1, started by a connection to port 5901
  (`vnc-proxy.socket` and `systemd-socket-proxyd`, which stops it after 30 idle minutes); TLS and a VNC
  password, new in OpenBao at `kv/homelab/agent-1-vnc`. Also the OpenBao CLI 2.7.3 (its server unit off),
  pipx, and DNS through Cloudflare over TLS: the router's dnsmasq answers nothing for public names that
  point at tailnet addresses, such as OpenBao's.
- Claude Code's `skipDangerousModePermissionPrompt`, as on the workstation: without it Orca's first worker
  stopped at the bypass-permissions prompt.
- Claude Code's working setup from the owner's workstation (what it holds is recorded in
  `homelab-private`); both repos cloned into `~/projects`; this repo's mise tools, git hooks and skill
  links set up.

## Snapshot / backup taken

None: new packages, files and user services only; nothing on agent-1 is backed up yet (plan, B0).

## How it was verified

- Orca: from the owner's Orca, `worker-start --on agent-1` with Claude Code ran a read-only task (hostname,
  a row of `lab/inventory/hosts.md`, its row count) and its task shows completed. agent-1's own Orca also
  logs the report as "unknown dispatch", which is noise: the task lives on the owner's Orca.
- Desktop: a TCP connection to 5901 got `RFB 003.008` and started Xvnc and Xfce; stopping the proxy
  stopped the desktop (after `--no-block` fixed a stop that deadlocked for 90 s); the socket stayed open.
- OpenBao's name resolves on agent-1 after the DNS change, and the OpenBao CLI reaches it.
- `agent.yml`: each change run, then a second run with 0 changed.
- In `~/projects/homelab` on agent-1: OpenTofu 1.13.2, ansible-playbook 2.21.5 and rclone 1.76.0 run; hooks on.

## Still open

Backups of `/home/aman` (owner: decide later).
