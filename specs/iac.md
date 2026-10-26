---
id: iac-provisioning
type: module-design
title: iac — VMs as code
status: draft
parent: arch-homelab
---

# iac

**Responsibility.** Turn a VM from a sentence into a running, first-booted VM:
the OpenTofu provider, the VM resource shape, and the cloud-init payload that
gives it a hostname, keys, and an address.

**Owns.** `iac/`. `provider.tf` is the only real configuration file; `vm.tf` and
`vault.tf` are copies of the examples and are git-ignored.

**Boundary.** It does not configure the VM after boot — that is Ansible or
Compose, and neither is in this repo. It does not hold credentials: the Xen
Orchestra token comes from the environment or from OpenBao (`secrets-openbao`).

## State

Local and git-ignored, one per checkout. Nothing enforces a single writer, and
nothing stops two checkouts from planning against different states.

## The contradiction to resolve

"Reproducible from code" and "`vm.tf` is git-ignored so local names never leak"
cannot both be true. A git-native lab needs the VM definitions committed and the
*secrets* kept out instead — which the `.example` split already does for
credentials, but not for topology.

## Unconfirmed — research needed

- **State backend:** none chosen (see `arch-homelab`).
- **Ansible:** the README claims it exists; the repo has no playbooks. Whether it
  belongs to this module or gets its own is undecided.
- **cloud-init:** committed template per VM, or generated — undecided.
