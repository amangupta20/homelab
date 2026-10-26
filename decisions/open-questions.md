# Open questions

Everything undecided, or written down but never checked against the live lab.
One list, so nothing hides in a section of some other page.

Agents append here when they find a contradiction or a claim they cannot
verify — and stop there, rather than picking a side. Only the owner resolves an
item; when resolved, it becomes a decision in this folder or a fact in its
owner file, and is deleted from this list.

## Nothing verified yet

- The docs were written from memory, not from an audit. Every service, host,
  schedule and retention setting is unconfirmed until the read-only recon pass
  compares it to the live lab.

## Platform (XCP-ng, Xen Orchestra)

- Do the live XO backup schedules and retention match `ops/backup-restore.md`?

## Backups

- Where does the offsite copy land, and is it encrypted at rest?
- Does OpenBao's backup travel the same offsite path or need its own?

## Provisioning (`iac/`)

- "Reproducible from code" and "`vm.tf` is git-ignored so local names never
  leak" cannot both be true. A rebuildable lab needs VM definitions committed
  with only secrets kept out. Which names are actually sensitive in a public
  repo?
- Ansible: the README named it as the after-boot configuration tool, but the
  repo has no playbooks. Is it still the plan?
- cloud-init: one committed template per VM, or generated?

## Secrets (OpenBao)

- Storage backend: Raft on local disk (likely) or PostgreSQL. The first draft
  of the setup guide used the file backend; whether that backend is still supported
  upstream has not been checked.
- Auto-unseal: undecided. Without it, every restart needs a human with the keys.
- Delivery to homeserver containers: a sidecar writing `/run/secrets` is the
  working assumption; a container manager with native vault support would
  replace it.

## Container runtime (homeserver)

- Portainer replacement: Arcane is the likely candidate, Komodo the
  alternative. Nothing chosen or tested.
- Does the chosen manager read OpenBao natively?
- Which of the three-year-old stacks are worth migrating, and which get retired?

## Remote VPS (Dokploy)

- Where its definitions live: its own folder, or next to the homeserver apps.
- How Dokploy deploys from this repo, and whether it keeps its own copy of
  each stack.
- Which apps run on it — not documented yet.

## Not planned yet

- SSO: wanted, undecided. Authentik was used before and dropped — reason not
  recorded.
- Observability: wanted, not deployed. Prometheus/Grafana is an assumption,
  not a choice. Whether Uptime Kuma runs at all is unknown
  (`inventory/services.md`).
