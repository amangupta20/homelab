#!/usr/bin/env python3
"""Check the page properties the Obsidian view reads (repo/obsidian-view.md).

Every page in systems/, inventory/ and plans/ starts with a small YAML block.
The Bases tables in bases/ are built from it, so a missing or misspelled
property silently drops a page from the dashboard. This fails loudly instead.

Standard library only: the property block is a restricted YAML subset
(`key: value` and `key:` followed by `  - item` lines), parsed by hand.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOLDERS = {"systems": "system", "inventory": "inventory", "plans": "plan"}
ALLOWED = {"type", "status", "verified", "hosts", "tags"}
REQUIRED_PAGE = {"type", "status", "verified", "tags"}
REQUIRED_INDEX = {"type", "tags"}


def parse(text):
    """Return the property dict, or None when the page has no block."""
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    props, key = {}, None
    for line in m.group(1).split("\n"):
        if not line.strip():
            continue
        item = re.match(r"\s+- (.*)$", line)
        if item and key:
            props[key].append(item.group(1).strip().strip('"'))
            continue
        kv = re.match(r"([A-Za-z_]+):\s*(.*)$", line)
        if not kv:
            raise ValueError(f"cannot read property line: {line!r}")
        key, value = kv.group(1), kv.group(2).strip().strip('"')
        props[key] = [value] if value else []
    return props


def host_names():
    """First column of the table in inventory/hosts.md, the host list's owner."""
    names, in_table = set(), False
    for line in (ROOT / "inventory/hosts.md").read_text().splitlines():
        if line.startswith("| Host |"):
            in_table = True
            continue
        if in_table:
            if not line.startswith("|"):
                break
            cell = line.split("|")[1].strip()
            if cell and not set(cell) <= {"-", ":"}:
                names.add(cell)
    return names


def main():
    errors = []
    hosts = host_names()
    for folder, base_type in FOLDERS.items():
        for page in sorted((ROOT / folder).glob("*.md")):
            rel = page.relative_to(ROOT)
            try:
                props = parse(page.read_text())
            except ValueError as e:
                errors.append(f"{rel}: {e}")
                continue
            if props is None:
                errors.append(f"{rel}: no property block at the top")
                continue
            is_index = page.name == "README.md"
            want_type = f"{base_type}-index" if is_index else base_type
            got_type = (props.get("type") or [""])[0]
            if got_type != want_type:
                errors.append(f"{rel}: type is {got_type!r}, expected {want_type!r}")
            for key in sorted(set(props) - ALLOWED):
                errors.append(f"{rel}: unknown property {key!r} (allowed: {', '.join(sorted(ALLOWED))})")
            for key in sorted((REQUIRED_INDEX if is_index else REQUIRED_PAGE) - set(props)):
                errors.append(f"{rel}: missing property {key!r}")
            for key in ("status", "verified", "tags"):
                if key in props and not any(props[key]):
                    errors.append(f"{rel}: property {key!r} is empty")
            for host in props.get("hosts", []):
                if host not in hosts:
                    errors.append(f"{rel}: host {host!r} is not a row in inventory/hosts.md")

    home = ROOT / "Home.md"
    if home.exists():
        for target in re.findall(r"!\[\[([^\]|#]+)", home.read_text()):
            if not (ROOT / target).exists():
                errors.append(f"Home.md: embeds {target!r}, which does not exist")

    for e in errors:
        print(f"check-properties: {e}", file=sys.stderr)
    if errors:
        print("check-properties: see repo/obsidian-view.md for the schema", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
