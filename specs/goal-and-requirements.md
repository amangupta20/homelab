---
id: goal-homelab
type: goal-and-requirements
title: Homelab — the repo as the source of truth
status: draft
---

# Homelab

One bare-metal server running isolated VMs, plus a small remote VPS for the
public-facing parts. This repo is the record of what exists and why, so the lab
can be rebuilt, reviewed, and handed to an agent without a human memory in the
loop.

## Why

The lab grew by hand: containers clicked into a manager, `.env` files copied to
five checkouts, services nobody has touched in three years. That worked while
there was time to babysit it. The repo exists so the time is not needed.

## What it does today

- Documents services, network, platform rules, backup rules, and secret handling
  (`inventory/`, `platforms/`, `ops/`, `docs/`).
- Provisions VMs from OpenTofu examples, not definitions: `vm.tf` is git-ignored.
- Runs the homeserver's stacks in Portainer, configured by hand.
- Keeps secrets out of git by rule; OpenBao is documented but not deployed.

## What it should do

**Probably — each line still needs verifying before it is treated as true:**

- Hold VM definitions, cloud-init, host configuration, and application Compose
  files so a VM can be rebuilt from the repo alone. Proof would be one actual
  rebuild, not a review.
- Hold secret *paths* only, with the values in OpenBao.
- Run a plan before any change and a secret scan before any commit.
- Answer one question per file: what runs, what is exposed, what is backed up,
  what is untested.

## Principles

1. Isolation first — one VM per job; a bad VM stays in its box.
2. Rebuild, don't pet.
3. Zero-trust admin — Tailscale only, no public SSH.
4. A backup counts when a restore works.
5. One fact, one owner (`AGENTS.md`).
6. One commit, one change (`AGENTS.md`).

Where this lands in practice: `arch-homelab`.
