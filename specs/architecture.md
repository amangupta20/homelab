---
id: arch-homelab
type: architecture-design
title: Topology and module boundaries
status: draft
parent: goal-homelab
---

# Architecture

## Shape

XCP-ng on the bare metal, Xen Orchestra as its UI. VMs per job. Apps are Docker
Compose stacks inside those VMs. Provisioning is OpenTofu for the VM's shape and
cloud-init for its first boot. Admin reaches everything over Tailscale; public
traffic arrives Cloudflare -> Nginx Proxy Manager -> container.

## Modules

| Module | Owns | Depends on |
|---|---|---|
| `iac-provisioning` | VM definitions, cloud-init, state | `platform-xcp-ng`, `secrets-openbao` |
| `platform-xcp-ng` | hypervisor and Xen Orchestra rules | — |
| `secrets-openbao` | where secret values live and how workloads read them | `platform-xcp-ng` |
| `backups-restore` | what is protected and what proof exists | `platform-xcp-ng` |
| `container-runtime` | what runs on the homeserver's Docker host | `secrets-openbao`, `platform-xcp-ng` |
| `repo-guardrails` | secret scanning, commit shape, apply discipline | — |

`inventory/` is deliberately not a module: it is the fact store
(`inventory/services.md`, `inventory/network.md`) that every other file links to
instead of copying.

## Invariants

- No secret value in git — not in a file, a commit message, or a state file.
- State and `*.tfvars` stay out of git.
- A base snapshot is never deleted by hand; only Xen Orchestra merges or deletes
  it, and only after a verified backup.
- Nothing is applied that did not first produce a plan someone read.
- One fact, one owner.
- One commit, one change.

## Unconfirmed — research needed

- **OpenTofu state.** No backend is configured; state is local and git-ignored.
  Candidates are S3 on TrueNAS, external S3 with OpenBao transit encryption, or a
  managed TACOS. Nothing is chosen.
- **Homeserver container manager.** Portainer today; Arcane is the likely
  replacement; Komodo and anything with native vault support are alternatives.
  Nothing is chosen.
- **SSO.** Planned, undecided. Authentik was a previous setup and was dropped.
- **Observability.** Planned, not deployed. Prometheus/Grafana is an assumption,
  not a fact.
- **Nothing here was verified against a running system.** The graph is drafted
  from documents, not from an audit.
