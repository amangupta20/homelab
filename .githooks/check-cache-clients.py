#!/usr/bin/env python3
"""The LAN cache rule (ansible/README.md, "Adding a host").

Every host in the inventory's `xcpng` group (the home VMs) must be in exactly
one of `lan_cache_clients` (apt and Docker through cache-1, set by
ansible/cache-client.yml) or `lan_cache_exempt` (with a reason in a comment).
A new VM that is in neither fails here, so it cannot quietly pull straight from
the internet. Run by the pre-commit hook and CI; needs PyYAML.
"""
import sys
from pathlib import Path

import yaml

INVENTORY = Path(__file__).resolve().parent.parent / "ansible" / "inventory.yml"


def hosts(group: dict | None) -> set[str]:
    """Hosts of a group, including those of its child groups."""
    if not group:
        return set()
    found = set((group.get("hosts") or {}).keys())
    for child in (group.get("children") or {}).values():
        found |= hosts(child)
    return found


def main() -> int:
    groups = (yaml.safe_load(INVENTORY.read_text())["all"].get("children") or {})
    vms = hosts(groups.get("xcpng"))
    clients = hosts(groups.get("lan_cache_clients"))
    exempt = hosts(groups.get("lan_cache_exempt"))
    errors = []
    for vm in sorted(vms - clients - exempt):
        errors.append(f"{vm}: in `xcpng` but not in `lan_cache_clients` or `lan_cache_exempt`")
    for vm in sorted(clients & exempt):
        errors.append(f"{vm}: in both `lan_cache_clients` and `lan_cache_exempt`")
    for vm in sorted((clients | exempt) - vms):
        errors.append(f"{vm}: in a LAN cache group but not in `xcpng`")
    if errors:
        print("LAN cache rule (ansible/README.md, \"Adding a host\"):", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        print("Add the host to `lan_cache_clients` and run ansible/cache-client.yml on it,\n"
              "or to `lan_cache_exempt` with the reason as a comment.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
