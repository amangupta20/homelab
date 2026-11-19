# Ansible — notes

When each playbook in `README.md` first ran, and what showed it worked.

## First runs

- `base.yml`: against `pigsty-1` on 2026-11-06. A second run changed nothing,
  and its firewall rule survived a reboot.
- `oob.yml`: first ran on 2026-11-14; a second run changed nothing, and its
  settings survived a power cycle.
- `common.yml`: on `xo-ce` and `cache-1` on 2026-11-16; a second run changed
  nothing.
- `xcpng.yml`: on `xo-ce` on 2026-11-16 (7.11.0 to 10.0.0; Xen Orchestra then
  reported agent 10.0.0-1 and the VM's addresses); a second run changed nothing.
  Also on `cache-1` right after it was built (2026-11-16); Xen Orchestra then
  reported agent 10.0.0-1 and its address.
- `cache.yml`: first ran on 2026-11-16
  (`agents/journal/2026-11-16-deploy-artifact-keeper.md`).
- `cache-client.yml`: first ran on `proxy-1` on 2026-11-18: `apt update` then
  fetched its lists from cache-1, a `docker pull` went through the mirror
  (cache-1's log), and a second run changed nothing.
- `proxy.yml`: first ran on 2026-11-18
  (`agents/journal/2026-11-18-build-proxy-1-traefik.md`).
- Pigsty: `--check` against `pigsty.yml` passed on 2026-11-06.

## History

- The LAN cache check (`.githooks/check-cache-clients.py`) was added on
  2026-11-18, after `proxy-1` was built pulling straight from the internet.
- `~/.ssh/pigsty` was created on the owner's workstation on 2026-11-06.
