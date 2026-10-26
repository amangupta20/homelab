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

Decided: one S3 bucket in Garage on TrueNAS (`homelab-tofu-state`, key
`xcp-ng/terraform.tfstate`), declared in `iac/backend.tf`, with credentials from
the environment rather than the file. The provider is pinned by a committed
`.terraform.lock.hcl`.

Garage does not implement S3 conditional writes, so OpenTofu's native lockfile
cannot be used and `use_lockfile` is off. There is no atomic lock: exactly one
checkout runs `tofu apply`, everything else plans, and the plan is pasted into
the pull request first. A scheduled `tofu state pull` export goes offsite,
because losing the bucket loses the mapping between code and real VMs.

This backend has not been exercised against a real bucket. Everything checkable
locally — fmt, validate, tflint, provider lock — passes.

## The contradiction to resolve

"Reproducible from code" and "`vm.tf` is git-ignored so local names never leak"
cannot both be true. A git-native lab needs the VM definitions committed and the
*secrets* kept out instead — which the `.example` split already does for
credentials, but not for topology.

## Unconfirmed — research needed

- **Ansible:** the README claims it exists; the repo has no playbooks. Whether it
  belongs to this module or gets its own is undecided.
- **cloud-init:** committed template per VM, or generated — undecided.
