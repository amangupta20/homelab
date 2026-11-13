---
type: idea
status: "researched"
verified: "no (research only, 2026-10-25 to 2026-11-01; nothing built or tested)"
tags:
  - idea
  - security
  - edge
  - reverse-proxy
  - waf
  - crowdsec
  - pangolin
---

# Edge and security layers

**Status:** researched — on hold until the owner decides on Pangolin
(owner, 2026-11-01). Nothing here is decided unless it says so.
**In one line:** how public traffic should reach the lab and which security
tool sits at which layer — Cloudflare, the edge proxy and its web application
firewall (WAF), a ban tool to replace Fail2Ban, sign-in, Tailscale and DNS,
network segmentation, detection, hardening and penetration testing.
**Why try it:** the edge proxy decides how every migrated service is exposed
and which WAF, ban tool, sign-in layer and wakeup plugin
(`ideas/on-demand-container-wakeups.md`) can sit in front of it. The research
was spread over a week of conversations and partly forgotten; this page
collects it so the decision can be made once.
**Needs first:** the Pangolin decision (below). The other parts follow from
it in the order under "Decision order".

Sources, unless a line says otherwise: Hindsight (the owner's shared agent
memory) for conversations dated 2026-07-19 (Pangolin), 2026-10-25/26
(CrowdSec, security agents), 2026-10-27 (DNS, NPM, router) and 2026-11-01
(owner corrections); GitHub's API and vendor documentation read on
2026-11-01 for versions, licences and paywalls; the security-agents research
notes from 2026-10-26 kept outside this repo. Versions and dates are as read
on 2026-11-01. A version number on this page is the latest upstream release,
never what the lab runs; installed versions are not recorded here.

## Decision order

Each choice constrains the next:

1. **Pangolin or not** — whether home keeps inbound ports at all.
2. **The home edge proxy** — and with it, which WAF engine can run.
3. **Real client IPs and origin protection** for that edge.
4. **Where CrowdSec's local API (LAPI) and its bouncers live.**
5. **The forward-auth layer** for apps with no sign-in of their own (the SSO
   provider itself is not blocked; see "Sign-in").

Not blocked by any of this: SSO's identity provider on the VPS, wakeups on
the VPS (Dokploy's Traefik stays either way), Pigsty
(`plans/shared-postgres.md`), migrating internal-only stacks, Vuls, Nuclei
and the read-only security baseline (`plans/migration.md`, step 1).

## Layers at a glance

| Layer | Today (from docs, unverified) | Considered | State |
|---|---|---|---|
| Cloudflare | proxies and filters public names | custom WAF rules with a Country condition for geoblocking (works on the free plan, needs proxied records) | open |
| Getting in | Cloudflare → NPM (`inventory/network.md`) | Pangolin: no inbound ports at home | on hold |
| Edge proxy | Nginx Proxy Manager (NPM) | BunkerWeb, NPMplus, Caddy, Traefik, Pangolin's Traefik | open |
| WAF | Cloudflare only | CrowdSec AppSec, BunkerWeb (ModSecurity + OWASP Core Rule Set), Coraza, SafeLine, open-appsec | open |
| Ban tool | Fail2Ban | CrowdSec | CrowdSec preferred (owner, 2026-11-01) |
| Sign-in | per-app passwords | Pocket ID, Authelia, Kanidm; forward-auth by the edge | open |
| Admin and DNS | Tailscale only; AdGuard rewrites | AdGuard as the tailnet's DNS; a private proxy behind Tailscale | open |
| Segmentation | one VM per job | a virtual router VM on XCP-ng | deferred |
| Detection | ntfy alerts, OpenBao audit log | Wazuh, Vuls, Suricata, Security Onion, Falco | deferred, except Vuls |
| Testing | none | Nuclei now; Strix later, isolated | open |

## Getting in: Pangolin (maybe)

Pangolin is a self-hosted tunnel and access platform: a server on a VPS
(dashboard, users, access rules) with Traefik, its sign-in plugin Badger, and
the WireGuard manager Gerbil. At home, a small connector, Newt, dials *out* to
the VPS, so home needs no inbound port (Pangolin docs, system architecture).
Public traffic goes Traefik → Badger → Gerbil → tunnel → Newt → app; raw
TCP/UDP is supported but skips Badger.

- **Why it was considered** (Hindsight, 2026-07-19): drop the paid static IP
  and remove inbound port forwards at home. The value is segmentation and
  less inbound exposure, not hiding the address — scanners find dynamic
  addresses anyway.
- **Gate before cancelling the static IP** (same source): run Pangolin on the
  ordinary dynamic connection for a few days, confirm it survives WAN address
  changes and that the ISP allows the outbound UDP.
- **Behind Cloudflare** (Pangolin docs, "Cloudflare proxy"): SSL mode must be
  Full (Strict); Badger 1.3.0+ trusts Cloudflare's ranges and reads
  `CF-Connecting-IP`; set `trust_proxy: 2` and `base_endpoint` to the VPS
  address.
- **CrowdSec:** the installer can add it (Pangolin docs); community guides
  report extra work on trusted IPs. How CrowdSec and Cloudflare's real-IP
  handling combine is not documented anywhere found.
- **Wakeups across the tunnel:** the edge Traefik cannot see home's Docker, so
  Sablier would run at home with its API reachable from the edge, and the
  middleware attached per resource — Pangolin's UI cannot, the community
  Middleware Manager can (users report 404s from it). No source documents
  Sablier with Pangolin. Simpler: Newt hands sleepable apps to a small
  Traefik at home that holds Sablier, or keep wakeups on the VPS only.
- **Where it runs:** an Oracle E2.1.Micro (1 GB RAM; Hindsight records a
  50 Mbps cap) or the existing A1 VPS if it has about 2 GB spare (Hindsight,
  2026-07-19). All public home traffic then crosses that VPS; if it is down,
  public home apps are down (admin over Tailscale is not affected).
- **ARM:** `fosrl/pangolin` 1.25.3, `fosrl/gerbil` 1.5.2 and `fosrl/newt` 1.19
  are published for arm64 (Docker Hub manifests, read 2026-11-01); Badger is a
  Traefik plugin interpreted at runtime, so the CPU type does not matter.
  Nothing has been run here.
- **Licence:** Community Edition AGPL-3.0; an Enterprise Edition under the
  Fossorial Commercial License is free for personal use (README).

Sketch with Pangolin (UNTESTED design):

```
visitor → Cloudflare (orange cloud, Full Strict; WAF rules, geoblock)
        → edge VPS: Traefik → CrowdSec bouncer + AppSec → Badger (sign-in) → Gerbil
        ══ WireGuard, outbound from home ══
        → home edge VM: Newt → (optional) BunkerWeb with ModSecurity + CRS → app VMs
admin: Tailscale only, unchanged     internal names: private proxy, unchanged
VPS1 (Dokploy): its own Traefik, DNS-only, unchanged at first
```

Option A uses the edge Traefik with CrowdSec AppSec as the only WAF: one
proxy. Option B adds BunkerWeb at home behind Newt for full in-band CRS: two
proxies, and BunkerWeb must trust the edge's `X-Forwarded-For`.

## The edge proxy

The owner is not tied to NPM; what made NPM good was configuring it in a UI
(owner, 2026-10-31 and 2026-11-01). The split into two NPM instances (public
and private, separated by listener), approved on 2026-10-27, is **back to
research** (owner, 2026-11-01).

| | Click-to-configure UI | WAF | Sablier | CrowdSec | Logs and dashboards |
|---|---|---|---|---|---|
| NPM | yes | none ("Block Common Exploits") | no | no | basic |
| NPMplus (AGPL-3.0, fork of NPM) | NPM's | CrowdSec AppSec | no | built in | basic |
| BunkerWeb (AGPL-3.0, v1.6.17) | yes, including security settings | ModSecurity + CRS, free | no plugin (see below) | yes | free Metrics page, log viewer, reports |
| Caddy (Apache-2.0, v2.11.7) | no: a Caddyfile, or labels via caddy-docker-proxy | Coraza, compiled in | native module | bouncer with AppSec | bring your own |
| Traefik (MIT) | read-only dashboard; Dokploy, Mantrae (pre-1.0) or Pangolin to edit | CrowdSec AppSec; Coraza only as a slow WASM plugin | native plugin | plugin with AppSec | traefik-log-dashboard (AGPL-3.0) |
| Pangolin | yes, Traefik underneath | through CrowdSec | possibly, through its Traefik (unverified) | installer option | its own UI |

- **Caddy upkeep:** WAF, CrowdSec and Sablier modules are compiled in with
  `xcaddy`, so the lab keeps a small image build and rebuilds it on every
  Caddy release.
- **Traefik upkeep:** plugins are one static-config entry each, no build.
- **BunkerWeb and Sablier:** Sablier's nginx support is a Proxy-Wasm module
  BunkerWeb cannot load, and no integration exists (GitHub search,
  2026-11-01). A Sablier plugin only calls one Sablier endpoint and reads the
  `X-Sablier-Status` header (`ready` / `not-ready`) (Sablier docs,
  strategies), so three paths remain: a small Lua plugin of our own
  (BunkerWeb plugins are Lua; UNTESTED), BunkerWeb handing sleepable hosts to
  a Traefik or Caddy that holds Sablier, or wakeups on the VPS only.

### What BunkerWeb keeps behind PRO

From BunkerWeb's feature documentation (read 2026-11-01), where each PRO
plugin is labelled. PRO checks a licence key with BunkerWeb's server and then
downloads its plugins; a 30-day trial exists; a BunkerWeb page listed
€15/month per service (possibly out of date).

**Free:** the web UI (services, settings, bans, jobs, log viewer, reports,
2FA), ModSecurity with CRS, antibot including Cloudflare Turnstile, bad-behaviour
bans, CrowdSec, Let's Encrypt including wildcard certificates over DNS-01,
real IP, country blocking, rate limits, mTLS, basic auth, custom nginx and
ModSecurity snippets, scheduled local backups with rotation and restore,
Metrics.

| PRO feature | What it does | By hand instead |
|---|---|---|
| Backup S3 | uploads backups to S3 | free Backup writes them to a folder; ship it to Garage/B2 like other services (`skills/back-up-a-service/`) |
| Monitoring | internal plugin that Reporting needs | — |
| Prometheus exporter | `/metrics` for Grafana | access logs into GoAccess or Loki/Grafana; CrowdSec's own metrics |
| Reporting | weekly email or webhook summary | a cron job against BunkerWeb's API posting to ntfy (UNTESTED) |
| OpenID Connect, SAML, LDAP, UI SSO | sign-in at the proxy | an nginx `auth_request` snippet to Authelia or Pocket ID's helper (UNTESTED) |
| Easy Resolve | one-click whitelist of a false positive | write the ModSecurity exclusion |
| Wildcard | one service answering `*.domain` | not needed; wildcard certificates are free |
| Anti-DDoS, load balancer, cache, custom error pages, User Manager, custom ACME CAs, OpenAPI validator, maintenance, migration | — | mostly not needed here |

Logging is not limited: the free log viewer reads `/var/log/bunkerweb`, fed
by a syslog sidecar (BunkerWeb Web UI docs).

## Cloudflare, and traffic that skips it

- **Proxied or DNS-only is forced per app by the free plan** (Hindsight,
  2026-10-25 to 29): the free certificate covers `*.domain` but not
  `*.sub.domain`, and proxied requests are capped at 100 MB, so some names
  have to be DNS-only. Workarounds: flat names
  (`app-sub.domain`), Cloudflare's Advanced Certificate Manager ($10/month),
  or DNS-01 certificates at the origin.
- **Origin protection is a requirement for whichever edge is chosen.** If the
  origin's address is known, a client can connect to it directly with the
  right hostname (for example `curl --resolve`) and skip Cloudflare. Options,
  cheapest first: accept 80/443 only from Cloudflare's published ranges (kept
  current); Authenticated Origin Pulls with a certificate for this zone
  (Cloudflare presents it, the proxy requires it); no inbound ports at all
  (Pangolin or a Cloudflare Tunnel); always a 404 for unknown hostnames.
- **Real client IPs** must be restored before any ban tool or WAF runs behind
  Cloudflare, or it bans Cloudflare itself: Traefik
  `forwardedHeaders.trustedIPs`; nginx `set_real_ip_from` plus
  `real_ip_header CF-Connecting-IP`; Docker's published ports rewrite the
  source address unless the container uses the host network.
- **Cloudflare Tunnel caveat** (Hindsight, 2026-10-26): routes that go from a
  tunnel straight to a service skip the proxy, and nothing reads cloudflared's
  log by default.

## Internal names

The owner's design (owner, 2026-11-01; accepted 2026-10-27 per Hindsight): a
separate internal proxy, and a Cloudflare record pointing a wildcard
(`*.home.<domain>`) at that proxy's private address.

- What protects it is that the internal proxy has no public listener — no
  port forward, no UPnP, no public IPv6 — not the DNS record: anyone can look
  the name up, but gets a private address they cannot route to. If the proxy
  ever became reachable, the public wildcard would make guessed names usable.
- Use a wildcard DNS-01 certificate so hostnames never appear one by one in
  public certificate-transparency logs.
- Some routers and resolvers drop answers that point at private addresses
  (DNS rebinding protection); untested on this ISP's router.
- Off the LAN it resolves only to something reachable over Tailscale's
  subnet route. Recommended alongside (Hindsight, 2026-10-27): AdGuard as the
  tailnet's global nameserver with MagicDNS. Whether the internal proxy sits
  behind Tailscale too is open (owner, 2026-11-01).

## Ban tool: CrowdSec instead of Fail2Ban

CrowdSec is the preferred replacement (owner, 2026-11-01). Fail2Ban is not
written off: it works once real IPs are restored and on anything directly
reachable (owner, 2026-11-01).

How CrowdSec is built (CrowdSec docs, via Hindsight 2026-10-26):

- **Security engine (agent)**, one per host: reads logs, parses them, matches
  scenarios, raises alerts. Its **AppSec** component is a WAF on port 7422:
  virtual patches for known CVEs block in-band; CRS runs out-of-band and bans
  after five matches.
- **Local API (LAPI):** stores decisions; one for the lab, other hosts' agents
  register to it over Tailscale.
- **Bouncers:** enforce decisions where traffic passes — the proxy, the host
  firewall, Cloudflare (the Workers bouncer; avoid the old Cloudflare bouncer,
  which uses a frozen API and is reported to crash).
- **Central API:** the community blocklist (about 3,000 addresses in the free
  "Lite" list if the lab does not share signals) and an optional console.

| Place | Agent reads | Bouncer |
|---|---|---|
| VPS | Traefik access logs, sshd journal | Traefik plugin (maxlerebourg, v1.8.1) with AppSec, set to block when AppSec is unreachable; firewall bouncer, tested first against Docker's chains given `journal/2026-10-29-hindsight-down-stale-firewall-rules.md` |
| Home edge | proxy logs (NPM needs type `nginx-proxy-manager`, not `nginx`, or nothing parses) | whatever the chosen proxy supports: NPMplus, Traefik plugin, Caddy bouncer, BunkerWeb |
| Cloudflare | — | Workers bouncer, for proxied names |
| Virtual router, if built | firewall logs | OPNsense's CrowdSec plugin (unverified) |

Open: where the LAPI lives — the VPS (always on, the same reasoning as
OpenBao in `decisions/foundations-on-vps.md`) or home. Known limit: log-based
bans arrive after the response, so a single-request exploit gets through;
AppSec's in-band virtual patching is what closes part of that.

## WAF engines

Two kinds: some *are* a reverse proxy (SafeLine, BunkerWeb) and replace or
sit in front of the edge; the rest are engines that only plug into certain
proxies. So the WAF follows the edge proxy.

| | Kind | How it detects | Licence, release | Plugs into | Notes |
|---|---|---|---|---|---|
| SafeLine (Chaitin) | own reverse proxy + UI | semantic analysis of SQL/JS | GPL-3.0, v9.4.3 | in front of everything | free-edition limits reported inconsistently (about 10 apps); most reviews are vendor-affiliated; adds a hop |
| BunkerWeb | nginx reverse proxy + UI | ModSecurity + CRS, plus bans, antibot | AGPL-3.0, v1.6.17 | replaces NPM | paywall above |
| ModSecurity v3 + CRS | engine | rules (CRS v4.30.0) | Apache-2.0, v3.0.17; nginx connector v1.0.4 (2025-05) | nginx, Apache | now an OWASP project; most tuning |
| Coraza | engine, Go | rules, CRS-compatible | Apache-2.0, v3.8.1 | Caddy (v2.6.2), HAProxy, Envoy; Traefik via WASM | Traefik's own benchmark: WASM plugin 29 req/s vs 683 for the paid Traefik Hub version (2024-09); CrowdSec AppSec embeds Coraza |
| open-appsec (Check Point) | engine | machine learning plus few rules | Apache-2.0, v1.1.36 | nginx, an NPM build (MIT, last release 2025-11), SWAG, Kong, APISIX; no Traefik found | local file or Check Point's cloud portal |
| CrowdSec AppSec | in CrowdSec | virtual patches in-band, CRS out-of-band | MIT, CrowdSec v1.8.2 | NPMplus, Traefik, Caddy, nginx/OpenResty | comes with CrowdSec |

Out: NAXSI (original archived 2023, fork slow), Janusec (licence unclear),
Nemesida WAF Free (not on GitHub), Wallarm (commercial). Cloudflare's WAF
stays as the first layer whatever is chosen.

Suggested baseline (agent's judgement, untested): CrowdSec AppSec everywhere,
full in-band CRS only for apps worth the tuning, run in detection-only mode
first — false positives are where CRS costs time.

## Sign-in

- The SSO provider (Pocket ID, Authelia, Kanidm; Authentik found too heavy in
  a 2024 trial, not final) runs on the VPS, public, admin tailnet-only, with
  its own bundled database (`decisions/foundations-on-vps.md`,
  `decisions/open-questions.md`). All three are OpenID Connect providers, and
  every edge candidate can use one, so **choosing and deploying the provider
  is not blocked by the edge decision.**
- Only forward-auth — a sign-in in front of apps with none of their own —
  depends on the edge. With Pangolin, Badger does it and can use an external
  provider, which favours a plain provider like Pocket ID. Without Pangolin,
  the proxy needs Authelia's forward-auth or a helper such as oauth2-proxy
  next to Pocket ID or Kanidm.
- Loops to avoid: SSO must not depend on Pigsty; OpenBao's break-glass and
  unseal must not depend on SSO; Pigsty and its dashboards keep a local login.

## Network segmentation (deferred)

- **Virtual router** (owner, 2026-11-01, not settled, probably deferred):
  OPNsense or similar as a VM on XCP-ng, the ISP on its outside interface,
  homelab VMs on an internal XCP-ng network behind it. It would host
  segmentation by VLAN (edge, services, management, an audit VLAN for Strix),
  the Cloudflare-only allowlist, a CrowdSec bouncer, Suricata, and a mirror
  port for Security Onion. Keep XCP-ng's and Xen Orchestra's management
  interface, and the out-of-band Raspberry Pi, outside it so the host stays
  reachable when the router VM is down. Checksum offload in pfSense/OPNsense
  guests on Xen is a known issue, as recalled (unverified).
- **Physical router** (Hindsight, 2026-10-27): the ISP router locks DHCP and
  DNS; bridge mode or passthrough to an owned OpenWrt/OPNsense router was the
  long-term recommendation. Since 2026-11-12 an owned OpenWrt router
  sits behind the ISP router, which still routes (`systems/router.md`).
- **Earlier layout** (Hindsight, 2026-08-18): a critical VM for Tailscale and
  DNS, an edge VM as a kill switch, a main services VM, a 30-day soak VM, and
  a Raspberry Pi as out-of-band access and backup DNS.

## Detection and vulnerability management

| Tool | Layer | Fit here |
|---|---|---|
| Vuls | agentless; checks installed packages against CVE feeds over SSH | light, scheduled report; can start any time |
| Wazuh | host SIEM: agents plus manager, OpenSearch and dashboard; file integrity, CIS checks, vulnerabilities | about 4 vCPU / 8 GB (Hindsight, 2026-10-26); deferred until the ban layer works |
| Suricata | network intrusion detection | lightest network option; built into OPNsense |
| Security Onion | full network monitoring distro (Suricata, Zeek, Elastic) | needs mirrored traffic and much RAM; only with the virtual router |
| Falco | container runtime behaviour | not researched before; relevant given the agent containers |

CrowdSec, Fail2Ban and Suricata in IPS mode prevent; they do not detect a
compromise after the fact. Today's detection is ntfy plus the OpenBao audit
log (`inventory/services.md`, "ntfy bus"; `systems/openbao.md`, "Audit log";
both from docs, not checked on the live lab).

## Hardening and penetration testing

The migration plan's order already covers it: a read-only security baseline
in step 1 and a re-hardening pass in step 3 (`plans/migration.md`). Tools
proposed for those steps (Hindsight, 2026-10-26): nmap or RustScan for
exposure from outside and across the LAN, Nuclei, Lynis, docker-bench, Trivy,
later Greenbone.

- **Nuclei** (MIT, v3.11.1): a scanner driven by community YAML templates,
  each a fixed check (a CVE present, an admin page exposed, a default login,
  a readable config file). It reports and changes nothing, so it can run on a
  schedule. The tool for now.
- **Strix** (Apache-2.0, v1.7.0): multi-agent penetration testing for web
  apps, APIs and source code. It proves each finding with a proof-of-concept
  exploit — it actually runs the attack — which can create accounts, change
  data or crash a service. It runs a Kali container with `SYS_ADMIN`,
  `NET_ADMIN`, `NET_RAW` and AppArmor unconfined, mounts targets writable,
  and needs roughly a 30B+ model with a 32k context. No knowledge of XCP-ng,
  TrueNAS or Tailscale. PR #1578 (optional PoC, read-only mounts) is still
  open (GitHub, 2026-11-01). Rules from the 2026-10-26 research: a dedicated
  VM on an isolated audit VLAN with no route to management interfaces; never
  a Tailscale key; read-only mounts; PoC off; results never in git. Verdict:
  for the public web apps, later.
- **Others reviewed:** Nebula (approval per command), Shannon (changes app
  state; not for production), PentestGPT (CTF-oriented), CAI (robotics),
  HexStrike (an MCP toolbox; own ranges only).
- Security tasks are framed defensively ("audit my own infra, read-only
  first, report, then harden"), and findings never go into this public repo
  (`AGENTS.md`).

## Risks and costs

- Every extra layer is another component in front of public traffic to
  patch, back up and debug.
- CRS-based WAFs cost tuning time in false positives.
- A Pangolin edge adds a failure point and a bandwidth ceiling for all public
  home traffic.
- Several community pieces are young or single-maintainer (Mantrae,
  Middleware Manager, CaddyManager, the Coraza Traefik plugin).

## Promote when

The owner decides on Pangolin. Then the edge proxy and CrowdSec placement
become a plan, and the decisions above go to `decisions/`.

## Sources

- Hindsight (`aman-mem`), recall and a reflect run on 2026-11-01 over the
  conversations dated above.
- Pangolin docs: system architecture, Cloudflare proxy; Pangolin README;
  forum.hhf.technology guides on CrowdSec and Middleware Manager (community).
- BunkerWeb docs: features, Web UI. Sablier docs: strategies.
- Traefik blog, "Exploring Traefik's WAF integration" (2024-09-03).
- GitHub API, 2026-11-01: release, licence and activity of every project
  named in the tables; usestrix/strix PR #1578.
- Docker Hub manifests, 2026-11-01: architectures of the Pangolin, Gerbil,
  Newt, Traefik, CrowdSec and BunkerWeb images.
- Unverified here: everything about the live edge; CrowdSec with Pangolin's
  real-IP handling; any sizing not attributed above.
