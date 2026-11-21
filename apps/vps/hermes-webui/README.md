# Second Hermes WebUI on the VPS

A second Hermes WebUI on the VPS for someone without lab access — a plain chat
page over a public domain, no Tailscale or SSH needed. The folder name is the
same as the upstream project; which Dokploy project it is and who uses it live
in Dokploy, not in this public repo.

**Status:** deployed on Dokploy — sign-in and a chat turn with a tool checked after the
latest update (`NOTES.md`, "Tested"). Its password comes
from OpenBao through Dokploy's secret provider. Backups are not set up yet; the
deploy and the update are recorded in
`agents/journal/2026-10-27-deploy-hermes-webui.md` and
`agents/journal/2026-11-21-update-hermes-webui.md`.

**Sign-in:** through Authentik by OIDC (application `hermes-webui-1`), for
members of the Authentik groups `hermes-webui-1` and `homelab-admins`. The
shared password still works too, until the owner drops it (`NOTES.md`, "Sign-in").

## Data and backups

- `hermes-webui-home` holds the state: sessions, agent memory, config, and
  the agent's code. The thing backed up.
- `hermes-webui-workspace` holds the files the chat works on.
- **Backups (UNTESTED):** the plan is both volumes to the Garage destination
  at home (step 9 of the skill), run once, with a restore tried per
  `lab/systems/backups.md` — a backup counts only when the restore works.
- Neither volume is shared with any other stack. The intent is that a restore
  touches this chat and nothing else — UNTESTED, never restored yet.

Everything else, word for word, is in `NOTES.md`: "Derived from", "Sign-in", "Deploying in
Dokploy", "First deploy: the agent in the volume", "Troubleshooting", "Upgrading",
"Tested".
