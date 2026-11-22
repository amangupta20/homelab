# 2026-11-22 — cache-1 ran out of memory; Grafana, Prometheus and node-exporter removed

**Who:** Claude Code (Opus 5.5), the owner  **Scope:** `cache-1`  **Mode:** write
**Task:** owner, in session: find why the cache stalled, then remove the Grafana stack (owner, 2026-11-22:
"we probably will wire it into proper observability later")  **Skill:** none

## What happened

- An install of DeepSeek Harness on agent-1 asked the cache for about 1,300 npm files it had not seen.
  cache-1 (1.5 GiB at most, no swap) ran out: 19 MiB available, load 8, npm got 503s and some fetches
  took 11 minutes, then SSH and HTTP stopped answering. Before that, per `docker stats`: backend 474 MiB,
  Grafana 356 MiB, PostgreSQL 160 MiB, web UI 90 MiB, Prometheus 35 MiB, Caddy 15 MiB, node-exporter
  12 MiB. The install was stopped; the owner rebooted cache-1 from Xen Orchestra.

## What changed

- `apps/homeserver/artifact-keeper/`: Prometheus, node-exporter and Grafana out of `compose.yaml`, the
  `/grafana/` route out of the Caddyfile, `grafana/` and `prometheus.yml` deleted; `ansible/cache.yml`
  no longer writes their files, secrets or folders. The backend's metrics listener stays.
- On cache-1, by hand: their config, secret files and data folders (`/srv/artifact-keeper/grafana`,
  `prometheus`) removed, and `docker image prune -af` (1.76 GB back).
- Left as they are: the Authentik application `cache-grafana` and the `grafana_*` fields in OpenBao.

## Snapshot / backup taken

None: the cache refills from upstream and its settings come from the repo (`agents/decisions/backup-tiers.md`).

## How it was verified

- Prometheus before removal, lower bounds (counters reset at restarts): about 14,000 requests; npm 391
  hits to about 3,240 misses, Debian 9 to 786 (mostly index metadata); 3.6 GiB stored of a 75 GiB quota;
  memory peaked at 1.5 GiB and was under 100 MiB available for 102 minutes; p95 latency 20 s over 24 h.
- `cache.yml --check --diff` showed only the removal; after the run four containers run, 804 MiB is
  available (478 MiB before), `/health` answers 200 and `/grafana/` 404.
- `tofu plan` in `iac/`: no changes, so the VM is still at 1.5 GiB (the owner saw "2 GB" in Xen Orchestra).

## Still open

- A rerun of `cache.yml` reports the stack task changed: the `pg-certs` one-shot container starts on every
  `compose up` and `changed_when` counts "Started" (before this change too).
