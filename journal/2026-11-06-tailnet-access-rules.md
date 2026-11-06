# 2026-11-06 — set access rules on the tailnet

**Who:** the owner, with Claude Code  **Scope:** Tailscale, `dockploy`, `pigsty-1`  **Mode:** write
**Task:** give servers only the access they need  **Skill:** none

## What changed

- Removed the default allow-all rule from the tailnet's access policy. The owner's own
  devices keep full access, and tagged servers reach only what a rule allows.
- Tagged `dockploy` and `pigsty-1`, which also turned off their Tailscale key expiry.
- The policy is kept in the private repo `amangupta20/homelab-private`, because it maps
  who can reach what. It holds no secrets.

## Snapshot / backup taken

None: this changes access rules only, and the previous policy was the default.

## How it was verified

- The console's policy matched the private repo's file, compared with a script.
- Saving the policy runs its tests, and it saved.
- From the owner's workstation: SSH to `pigsty-1` works, OpenBao answers unsealed, and
  Hindsight's health check returns 200.
- From `pigsty-1`, four connections that should be blocked timed out.
- `tailscale status --json` shows both servers tagged, with no key expiry.

## Still open

- `dockploy` to Garage has not been tested, because Garage is down. The owner knows of
  nothing else on it that needs the tailnet; a missing rule would only show once home is
  back.
- The first OpenBao snapshot since tagging has not run yet.
- The home subnet router still needs a tag when home is back.
