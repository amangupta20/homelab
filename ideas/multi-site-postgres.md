---
type: idea
status: "researched"
verified: "no (research only, from a conversation 2026-10-31; nothing built or tested)"
tags:
  - idea
  - postgres
  - database
  - disaster-recovery
---

# Multi-site Postgres: a standby on the VPS

**Status:** researched — not scheduled. Builds on `plans/shared-postgres.md`.
**In one line:** keep a read-only copy of the home database on the VPS that
follows every change a few seconds behind, and that the owner can promote to be
the database if home is lost.
**Why try it:** survive losing the whole home site (power, internet, hardware)
with seconds of data lost instead of a day; serve reads to VPS apps from a
nearby copy; and learn how production systems handle replication between
sites.
**Needs first:** `plans/shared-postgres.md` running at home with a tested
restore; a VPN link between home and the VPS (the tailnet already is one);
spare RAM and disk on the VPS, or a second VPS.

Everything below is from a research conversation on 2026-10-31 and general
knowledge of Postgres, Patroni and etcd. None of it has been run here.

## Design sketch

```
HOME — makes its own decisions, never waits on the VPS
  cluster pg-home: Postgres primary, Patroni, etcd (home only)
  HAProxy on each app host; pgBackRest → Garage + offsite tier
        │ asynchronous streaming replication over the VPN
        ▼
VPS — a "standby cluster": read-only, promoted by hand
  cluster pg-cloud: Postgres standby, its own Patroni, its own etcd
  HAProxy for VPS apps: reads from the local standby, writes go home
```

- **Asynchronous replication.** The home primary does not wait for the VPS
  before confirming a write. If home dies, the VPS has everything except the
  last moments not yet sent — usually under a second to a few seconds (guess,
  not measured). Synchronous replication would lose nothing but adds a full
  round trip to every write.
- **The VPS cluster is a standby cluster, not part of the home cluster.**
  Patroni calls this `standby_cluster`; Pigsty can build one (as recalled, via
  `pg_upstream` — check its docs). It keeps its own etcd so it depends on
  nothing at home when home is gone.
- **Promotion is manual.** A person decides home is really lost, then
  promotes. Automatic failover between sites is ruled out below.

### Why etcd must not span home and the VPS

Etcd (the small store Patroni uses to agree who the primary is) only accepts a
change when a majority of its members agree. With one member each at home, on
the VPS and on a third machine, a home internet outage leaves home with 1 of 3
— no majority — so Patroni stops the home primary from accepting writes, even
though home apps on the LAN could have kept working. A bad ISP day becomes a
database outage. Keeping etcd at one site avoids that; the network rules for
etcd are in `plans/shared-postgres.md` ("Network latency").

### Promotion runbook rule: isolate first, then promote

If home is only cut off rather than dead, promoting the VPS creates two
primaries that both accept writes (split brain); merging them back is manual
and slow. So the first step of any promotion is making sure home cannot accept
writes (power it off or stop Patroni there), and only then promoting the VPS
(`patronictl` on the VPS — it works without Pigsty's admin node). Failing back
afterwards: rewind the old home primary with `pg_rewind`, let it follow, then
switch over in a quiet moment.

### Reads served from the nearest copy (site affinity)

HAProxy can prefer one server and keep another as `backup`, used only when the
first is down:

```
# HAProxy at home, read service          # HAProxy on the VPS, read service
server home-db ... check                 server cloud-db ... check
server cloud-db ... check backup         server home-db ... check backup
```

This works for reads only. A read straight after a write may not see it yet on
the far copy (asynchronous lag). Writes always go to the single primary: if
the VPS HAProxy sent writes to the standby they would fail, and if the standby
had been promoted there would be two primaries. HAProxy health-checks
Patroni's REST API (`/primary`, `/replica`), so after a promotion every HAProxy
follows on its own. Pigsty's read service already prefers replicas with the
primary as backup, as recalled — check before relying on it.

## Other things researched with it

- **FerretDB** — speaks the MongoDB protocol and stores the data in Postgres,
  so apps that need MongoDB could share the same backups and restores. It
  covers common MongoDB features, not all; each app has to be tested on it.
  Pigsty has a module for it.
- **Multi-primary Postgres** (pgEdge/Spock, EDB's BDR) — both sites accept
  writes and conflicts are resolved afterwards. Off-the-shelf apps are not
  written for that. Interesting to learn, not to run apps on.
- **Distributed SQL** (CockroachDB, YugabyteDB) — built for many regions,
  only partly compatible with Postgres; many self-hosted apps will not run on
  them.

## Risks and costs

- Split brain if the promotion rule is skipped (above).
- Home upload speed limits how fast changes reach the VPS; the first full
  copy is the large transfer.
- Writes from VPS apps to the home primary pay a full internet round trip each;
  chatty apps are slow that way.
- Two sites to patch, monitor and keep credentials for.
- The Oracle free allowance on the VPS is shared with everything else running
  there.
- Replication copies mistakes instantly. It protects against losing a site,
  not against a bad migration or a deleted table — only backups and
  point-in-time restore do (`decisions/backup-tiers.md`).

## Promote when

`plans/shared-postgres.md` is done, the VPS has room, and the owner wants the
home site to be survivable rather than restorable from backup.

## Sources

Research conversation 2026-10-31 (agent, from general knowledge; nothing
checked against current Pigsty or Patroni docs except where said). Patroni
standby clusters and REST API endpoints: Patroni documentation, as recalled.
