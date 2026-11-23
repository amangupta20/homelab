# Homeserver apps

Compose stacks on home machines. Ansible deploys each from this folder.

| Folder | What it does | Deployed by |
|---|---|---|
| `artifact-keeper/` | the LAN's apt and container image cache, on `cache-1` | `ansible/cache.yml` |
| `traefik/` | the reverse proxy for `<app>.home.<zone>`, on `proxy-1` | `ansible/proxy.yml` |
| `technitium/` | the home's DNS resolver with ad and tracker blocking, on `oob-1` (the Raspberry Pi, not a VM) | `ansible/oob.yml` |

The other home stacks still live only inside Portainer and move here one at a
time (`agents/plans/home-overhaul.md`). Arcane will deploy from this folder,
once step B3 of that plan has checked it (the owner's choice).
