---
id: secrets-openbao
type: module-design
title: secrets — OpenBao
status: draft
parent: arch-homelab
---

# secrets

**Responsibility.** Keep every credential in one always-on place on the tailnet,
hand it to workloads at deploy time, and keep every value out of the repo.

**Owns.** The vault server, its unseal material, its storage, and the path
convention (`kv/homelab/<thing>`). `docs/secrets-openbao.md` is the human
explanation; this file is the contract.

**Boundary.** It does not enforce that secrets stay out of git — that is
`repo-guardrails`. It does not decide how a manager injects what it is handed —
that is `container-runtime`.

## Shape (probably)

- Always-on VM, Tailscale-only, TLS on 8200 even on the tailnet, root token
  deleted after setup, a policy per consumer rather than one shared token.
- Storage: probably Raft on local disk. PostgreSQL is the documented
  alternative and is easier to operate when a trusted Postgres already exists.
  The file backend is being deprecated upstream and is not a candidate.
- Backup: Raft snapshots to TrueNAS plus offsite, with one restore actually
  tested. Losing the store loses every secret at once.

## Unconfirmed — research needed

- **Storage backend:** Raft vs PostgreSQL — not chosen.
- **Auto-unseal:** not decided. Without it a restart needs a human with the keys.
- **Delivery:** a sidecar writing `/run/secrets` is the working assumption for
  Arcane/Komodo; a manager with native vault support would make the sidecar
  redundant. The remote VPS keeps using Dokploy's native provider.
- **Nothing is deployed.** This module is entirely a plan.
