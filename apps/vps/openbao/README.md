# OpenBao on the VPS

How OpenBao works and the rules around it: `lab/systems/openbao.md`. This page is
only about this stack.

**Status:** running on the VPS, unsealed; backup and restore
tested from Garage (`agents/journal/2026-10-29-restore-test-openbao.md`) and
from Backblaze B2 (`agents/journal/2026-10-31-restore-test-openbao-b2.md`).

## Deploying in Dokploy

Follows `agents/skills/deploy-on-dokploy/` steps 6 and 7, with these differences:

- **No domain.** A Dokploy domain would route OpenBao through the public
  Traefik.
- **Auto-deploy off.** Every restart comes back sealed (seen in the local
  test), and there is no auto-unseal, so a deploy on every push to `main`
  would lock every secret until someone unseals it.
- Environment: only `TAILSCALE_IP` (`.env.example`).

## Data and backups

- `openbao-data` holds the Raft data; `openbao-logs` holds the audit log,
  `/openbao/logs/audit.log`, declared in the config (tested locally).
- Backup details, schedule, and retention are owned by `lab/systems/backups.md`;
  restore tests are recorded in `agents/journal/2026-10-29-restore-test-openbao.md` (Garage)
  and `agents/journal/2026-10-31-restore-test-openbao-b2.md` (Backblaze B2).

Everything else, word for word, is in `NOTES.md`: "Derived from", "TLS", "Host scripts",
"Tested".
