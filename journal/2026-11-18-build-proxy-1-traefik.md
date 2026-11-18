# 2026-11-18 — proxy-1 built from code, Traefik serving `*.home` with a wildcard certificate

**Who:** Claude Code; the owner read the plan and asked for the apply  **Scope:** new VM `proxy-1` on the XCP-ng host, one DNS record in the lab's Cloudflare zone, one field added in OpenBao  **Mode:** write
**Task:** phase 1 of step B4a in `plans/home-overhaul.md` (the home proxy), moved ahead of B0 by the owner the same day  **Skill:** none

## What changed

- OpenBao: field `zone` added to `kv/general/cloudflare` (`bao kv patch`; the token in `zonedns` unchanged), so code
  can read the zone without it being in this public repo.
- `iac/`: the Cloudflare provider (5.29.0), `run.sh` reading its token and the zone, and `iac/proxy-vm.tf`.
  `./run.sh plan`: 2 to add, 0 to change, 0 to destroy; the owner read it, and `./run.sh apply` of the saved plan
  created both in 52 s:
  - VM `proxy-1`: Debian 13 template, 1 vCPU, dynamic memory 256 MiB to 1 GiB, a 10 GB disk on `Nvme`, UEFI with
    Secure Boot, power-on with the host, tags `managed-by-opentofu` and `proxy`, `10.22.33.138` by cloud-init.
  - DNS record `*.home.<zone>`, A, to `10.22.33.138`, DNS only, TTL 300.
  - State copied to Garage (`xcp-ng/20261118T141331Z.tfstate`).
- `ansible/common.yml` and `ansible/xcpng.yml` ran on `proxy-1`; then `ansible/proxy.yml` (check mode first) installed
  Debian's Docker and started Traefik 3.7.16 from `apps/homeserver/traefik/`, with one route, `cache.home.<zone>`, to
  `cache-1`'s port 80.
- Traefik got the wildcard certificate for `home.<zone>` and `*.home.<zone>` from Let's Encrypt over the DNS challenge
  through Cloudflare's API: from its first log line to "Server responded with a certificate", 37 s (container log).

## Snapshot / backup taken

None: a new VM and a new DNS record, nothing existing changed. `proxy-1` keeps no data that cannot be rebuilt from
the repo; losing its certificate only means a new one is requested.

## How it was verified

- Over SSH as `debian` with the homelab VM key: hostname `proxy-1`, `eth0` at `10.22.33.138/24`, `cloud-init status`
  `done`, Secure Boot enabled, one 9.3 GiB disk (the cloud-init drive was removed), `xe-linux-distribution` running,
  Traefik container healthy at 39 MiB.
- A second `./run.sh plan`: no changes. A second `ansible-playbook proxy.yml`: `changed=0`.
- The certificate served on `10.22.33.138:443` (`openssl s_client`): issuer Let's Encrypt, names `home.<zone>` and
  `*.home.<zone>`, valid until 2027-02-16.
- Over Tailscale, from the workstation away from home (`ip route get 10.22.33.138`: via `tailscale0`, through the
  router's subnet route; the name resolved through the workstation's own public resolver):
  `https://cache.home.<zone>/` 200 (the web UI), `/health` 200, `/grafana/` 302 to Grafana's login on the same name,
  `http://` 301 to `https://`, certificate valid.
- On the LAN, from `proxy-1` and `cache-1` (both resolve through the router): `https://cache.home.<zone>/health` 200,
  certificate valid.
- The router's dnsmasq answers `cache.home.<zone>` with `10.22.33.138` (`nslookup` on the router against
  `127.0.0.1`), with rebind protection on and `home.<zone>` in `rebind_domain`: the allowlist added on 2026-11-17
  works.

## Not verified

- From the VPS: the tailnet policy lets it reach only Garage on the home subnet (`homelab-private`'s policy), so its
  request timed out, as a request to `cache-1` directly did. That is intended, not a fault of the proxy.
- Certificate renewal (Traefik renews about 30 days before expiry, so first around mid-January 2027).
