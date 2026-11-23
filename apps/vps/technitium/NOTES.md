# Technitium on the VPS: notes

## Derived from

| Source | Version read | Taken |
|---|---|---|
| Technitium's `docker-compose.yml` (`TechnitiumSoftware/DnsServer`) | commit `366e303`, read 2026-11-23 | the health check, the `ip_local_port_range` sysctl for bridge networks, the config volume |
| Technitium's `DockerEnvironmentVariables.md` | same day | the first-start variables; they are read only when no config exists |
| Technitium's `APIDOCS.md`, "Initialize And Join Cluster" | same day | the join call below |
| Dokploy templates (`Dokploy/templates`, `blueprints/`) | same day | nothing: there is no Technitium template |

## Choices that differ from the sources

- **Pinned by digest**, the same one as the Pi's, instead of `latest`: the two
  cluster nodes should run one release.
- **Ports on the tailnet address only**, instead of on every address: a public
  resolver is abused for amplification attacks. Host networking is not used
  because systemd-resolved already holds `127.0.0.53` and `127.0.0.54` on port 53
  (`ss -lunpt` on the VPS, 2026-11-23).
- **No log volume:** logs stay in the config volume; nothing on the VPS reads them.

## Joining the cluster (once, after the first deploy)

Rehearsed on two throwaway 15.6.2 containers on agent-1 on 2026-11-23: the
secondary took the primary's settings, allowed list and catalog zones, and
answered a `home` name. Done against the real nodes on 2026-11-23
(`agents/journal/2026-11-23-deploy-technitium-vps.md`). From a machine on the tailnet
with an OpenBao token, sign in to the VPS node and call, as `POST` form fields:

```
<vps>:5380/api/admin/cluster/initJoin
  secondaryNodeIpAddresses=<the VPS's tailnet address>
  primaryNodeUrl=https://oob-1.dns.home.arpa:53443/
  primaryNodeIpAddress=<oob-1's LAN address>
  ignoreCertificateErrors=true          # the Pi's certificate is self-signed
  primaryNodeUsername=admin
  primaryNodePassword=<kv/homelab/technitium, admin_password>
```

The VPS reaches the Pi through the router's subnet route, and the Pi sees it as
the router's address; the Pi's firewall opens 53443 to that address only
(`ansible/oob.yml`).

## What the first join needed

- **A tailnet rule:** the main tailnet only let `tag:dokploy` reach Garage at home, so
  the join timed out. The owner added a grant from `tag:dokploy` to the Pi's
  address on TCP 53443 and TCP/UDP 53 (policy in `homelab-private`).
- **Zone transfers through the router:** the Pi sees the VPS as the router's address,
  which was not on the cluster catalog's transfer list, so only the empty catalog
  arrived. Without the cluster zone `dns.home.arpa` the VPS also lacked the TLSA
  records that let it trust the Pi's self-signed certificate, so every heartbeat
  failed (`RemoteCertificateNameMismatch, RemoteCertificateChainErrors`). Ongoing
  cluster calls do not use the join's `ignoreCertificateErrors`
  (`DnsServerCore/Cluster/ClusterNode.cs`). `ansible/oob.yml` now adds the router to
  that list; transfers still need the cluster's TSIG key. Then the zones arrived and
  the heartbeats passed.
- **One-way cluster at first:** the Pi's own Tailscale (the out-of-band tailnet)
  dropped packets from `100.64.0.0/10` that did not arrive on `tailscale0`, which
  included the VPS's replies when the Pi started a connection through the router. So
  the Pi listed the VPS as `Unreachable`. Fixed the same day: the Pi's Tailscale no
  longer hooks its own firewall rules (`lab/systems/notes/oob.md`, "Tailscale's
  firewall"), and both nodes list each other as `Connected`.
- **Dokploy, by its REST API** (`x-api-key`, the key in `kv/general/dokploy`): project
  and Compose service `technitium` from this repo's `main`, `autoDeploy` off, the two
  variables as `${{vault.openbao.dokploy/technitium:<field>}}`. Adding the project to
  the OpenBao provider failed with "Assignment references a project outside this
  organization": the assignment list still named a deleted project. Dropping that one
  entry and adding the new one in the same `vaultProvider.update` worked; the
  provider's connection test passed after.

## Rebuild

Deploy again from Dokploy, then join as above. Settings, users and zones come
from the Pi, so a lost volume loses only this node's stats and logs. If the
cluster still lists the old node, remove it on the Pi first (Administration,
Cluster).
