#!/usr/bin/env python3
"""Check the page properties the Obsidian view reads (agents/obsidian/obsidian-view.md).

Every page in systems/, inventory/, agents/plans/ and ideas/ starts with a small YAML block.
The Bases tables in agents/obsidian/bases/ are built from it, so a missing or misspelled
property silently drops a page from the dashboard. This fails loudly instead.

Standard library only: the property block is a restricted YAML subset
(`key: value` and `key:` followed by `  - item` lines), parsed by hand.
"""
import pathlib
import re
import sys

# The tree to check: the checkout this script sits in, or the folder given as
# the only argument. The reviewer runs main's trusted copy of this script on a
# pull request's tree (`check-properties.py .`), so it must not assume its own.
ROOT = (pathlib.Path(sys.argv[1]) if len(sys.argv) > 1
        else pathlib.Path(__file__).resolve().parent.parent).resolve()
FOLDERS = {"systems": "system", "inventory": "inventory", "agents/plans": "plan", "ideas": "idea"}
ALLOWED = {"type", "tags"}
REQUIRED_PAGE = {"type", "tags"}
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



def main():
    errors = []
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
            for key in ("tags",):
                if key in props and not any(props[key]):
                    errors.append(f"{rel}: property {key!r} is empty")

    home = ROOT / "agents/obsidian/Home.md"
    if home.exists():
        for target in re.findall(r"!\[\[([^\]|#]+)", home.read_text()):
            if not (ROOT / target).exists():
                errors.append(f"agents/obsidian/Home.md: embeds {target!r}, which does not exist")

    for e in errors:
        print(f"check-properties: {e}", file=sys.stderr)
    if errors:
        print("check-properties: see agents/obsidian/obsidian-view.md for the schema", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
