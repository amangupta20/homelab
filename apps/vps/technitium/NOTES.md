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
answered a `home` name. Against the real nodes it is **UNTESTED** until the
journal entry of the first deploy says otherwise. From a machine on the tailnet
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

## Rebuild

Deploy again from Dokploy, then join as above. Settings, users and zones come
from the Pi, so a lost volume loses only this node's stats and logs. If the
cluster still lists the old node, remove it on the Pi first (Administration,
Cluster).
