---
type: plan
status: "not started"
verified: "no (NetBox facts read from its repositories 2026-11-05; nothing installed on the lab)"
tags:
  - plan
  - netbox
  - inventory
---

# NetBox

**Status:** not started, and no date set. The owner wants to run NetBox
"sometime" (2026-11-05); nothing in this plan is scheduled yet.
**Goal:** NetBox holds the lab's VMs, their IPs and the services and ports on
each, filled and kept current by a sync from the live systems rather than by
hand.
**Done when:** a VM or service added to the lab appears in NetBox after the next
sync run with nobody typing it in, a test restore of NetBox's data has worked
(`systems/backups.md`), and `inventory/services.md` has a NetBox row.

## Why, and what went wrong last time

NetBox is an open-source web app and database that records what infrastructure
should exist, with a REST and GraphQL API other tools can read. The owner tried
it early in the homelab to list services, ports, VMs and IPs, did not yet know
what they were doing, and forgot about it (owner, 2026-11-05; that install is
not documented anywhere in this repo).

Why it lapsed is an inference, not something the owner said: a list that depends
on someone remembering to update it goes stale once they stop. So the sync is
part of this plan's goal, not an extra for later. It is also why
`inventory/network.md` and most rows of `inventory/services.md` are still
marked unverified.

## What NetBox gives and costs

Read from the NetBox repositories on 2026-11-05 unless marked otherwise.

- **It models what the first attempt wanted.** Virtual machines and IP addresses
  are built in, and an "application service" records something like an HTTP
  server on TCP/8000 on a device or VM (`docs/models/ipam/service.md`).
- **Containers are not a built-in object**, from memory, unverified. Check this
  in step 1: most homeserver apps are Docker stacks, so they may have to be
  recorded as services on the host VM.
- **It does not discover anything by itself.** It only stores what it is given
  (from memory, unverified).
- **What it takes to run.** `netbox-community/netbox-docker` provides a Compose
  file with five containers: NetBox, a background worker, Postgres and two
  Valkey (Redis-compatible) instances. How much CPU, memory and disk they use
  on this lab has not been measured.
- **Possible shortcut for the sync.** NetBox Labs publishes `netboxlabs/diode`
  (data ingestion) and `netboxlabs/orb-agent` (discovery agent). Both are
  actively updated. Neither has been tried here, and whether they read Xen
  Orchestra, Portainer or the router is unknown.

## Decide before step 1

- **Who owns the facts.** `AGENTS.md` gives every fact one owner, and today
  `inventory/network.md` owns IPs and `inventory/services.md` owns the service
  list. Three options: NetBox stays a read-only view fed from the same sources,
  `inventory/` is generated from NetBox, or NetBox replaces those files. Until
  the owner changes this, `inventory/` stays the owner.
- **Which host runs it.** Not chosen.
- **Which Postgres.** The Compose file's own container, or a database on the
  server in `plans/shared-postgres.md` if that exists by then.

## Steps

1. **Try it on a throwaway install.** Run the Compose file somewhere disposable,
   load a few real VMs and services, and see how Docker stacks fit its model and
   whether the owner actually opens it. — gate: the owner still wants it and has
   answered "Decide before step 1".
2. **Build the sync.** Read VMs and IPs from Xen Orchestra, containers and ports
   from Portainer, and leases from the router, using read-only credentials; try
   Diode and orb-agent first, and write a script if they do not fit. Credentials
   live in OpenBao (`systems/openbao.md`). — gate: a second run with nothing
   changed on the lab changes nothing in NetBox.
3. **Deploy it for real.** Install on the chosen host, reachable for admin only,
   with its secrets in OpenBao. — gate: the sync fills it without errors.
4. **Back it up.** Follow `skills/back-up-a-service/`. — gate: a test restore
   works.
5. **Schedule the sync and record it.** Add the `inventory/services.md` row and a
   `systems/netbox.md` page, and apply the fact-ownership decision. — gate: the
   "Done when" check passes.

## Links

- `inventory/network.md`, `inventory/services.md` — what NetBox would be fed
  from or replace
- `plans/shared-postgres.md` — possible home for its database
- `plans/migration.md` — the Portainer replacement would change the sync's
  container source
