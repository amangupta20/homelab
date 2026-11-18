#!/usr/bin/env python3
"""Doc rules for the repo clean-up; only offenders missing from the allowlist fail.

Checks, over tracked Markdown files:

- paths:  a repo path in backticks, or a relative Markdown link, points at a
          tracked (or git-ignored) file or folder. Journal entries are exempt:
          they keep the paths of their day (journal/README.md is not).
- dates:  no `YYYY-MM-DD` in table rows of the human pages (README.md,
          inventory/, systems/, apps/**/README.md). Dates belong in journal
          entries, which those pages link.
- lines:  length caps: AGENTS.md 40, app READMEs 40, journal entries 40,
          systems pages 150.
- rules:  each danger rule is spelled out only in its owner file, the root
          AGENTS.md and the README's first screen; elsewhere, link the owner.
- root:   the visible (not dot-) entries at the repo root are on a fixed list.

Today's offenders are listed in .githooks/check-docs-allow.txt as
`<check> <file> <count>`. A finding not covered there fails; so does an entry
that is now too high (lower it: the list only shrinks). For `lines` the count
is the allowed length, and an entry fails once the file fits the cap.

Standard library only. `--baseline` prints the list for today's tree; it was
used once to seed the file, and raising an entry is the owner's call.
"""
import pathlib
import posixpath
import re
import subprocess
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOW = ROOT / ".githooks" / "check-docs-allow.txt"

ROOT_ENTRIES = {
    "AGENTS.md", "CLAUDE.md", "README.md", "Home.md", "mise.toml",
    "secret-scan.toml", "secret-scan.local.toml.example",
    "agents", "ansible", "apps", "bases", "decisions", "iac", "ideas",
    "inventory", "journal", "plans", "repo", "systems",
}

DATE = re.compile(r"\b20\d\d-\d\d-\d\d\b")
BACKTICK = re.compile(r"`([^`\s]+)`")
LINK = re.compile(r"\]\(([^)\s]+)\)")

# Danger rules: (name, pattern, files allowed to spell it out).
RULES = [
    ("base-snapshot", re.compile(r"base snapshot", re.I),
     {"systems/xcp-ng.md", "AGENTS.md", "README.md"}),
    ("lan-cache", re.compile(r"LAN cache rule|lan_cache_clients", re.I),
     {"ansible/README.md", "AGENTS.md"}),
]


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True,
                          capture_output=True, text=True).stdout


def human_page(f):
    return (f == "README.md" or f.startswith(("inventory/", "systems/"))
            or (f.startswith("apps/") and f.endswith("/README.md")))


def journal_entry(f):
    """A dated journal entry; journal/README.md is a living page, checked like others."""
    return f.startswith("journal/") and f != "journal/README.md"


def cap(f):
    if f == "AGENTS.md" or (f.startswith("apps/") and f.endswith("/README.md")):
        return 40
    if journal_entry(f):
        return 40
    if f.startswith("systems/") and f != "systems/README.md":
        return 150
    return None


def findings():
    tracked = git("ls-files").splitlines()
    exists = set(tracked)
    for f in tracked:
        p = pathlib.PurePosixPath(f).parent
        while str(p) != ".":
            exists.add(str(p))
            p = p.parent
    tops = {f.split("/")[0] for f in tracked}
    md = [f for f in tracked if f.endswith(".md")]

    found = Counter()   # (check, file) -> count, or the length for `lines`
    detail = []         # human-readable lines
    candidates = []     # (file, line number, path) for the ignore check

    for f in md:
        lines = (ROOT / f).read_text().splitlines()
        limit = cap(f)
        if limit and len(lines) > limit:
            found[("lines", f)] = len(lines)
            detail.append(f"lines  {f}: {len(lines)} lines, cap {limit}")
        for n, line in enumerate(lines, 1):
            if human_page(f) and line.startswith("|") and DATE.search(line):
                found[("dates", f)] += 1
                detail.append(f"dates  {f}:{n}: {DATE.search(line).group()}")
            for name, pat, owners in RULES:
                if f not in owners and not journal_entry(f) and pat.search(line):
                    found[("rules", f)] += 1
                    detail.append(f"rules  {f}:{n}: restates the {name} rule")
            if journal_entry(f):
                continue
            for tok in BACKTICK.findall(line):
                if "/" in tok and tok.split("/")[0] in tops and not re.search(r"[<>*${}|\[\]]|\.\.\.", tok):
                    path = re.sub(r"(#.*|:\d+(-\d+)?)$", "", tok).rstrip("/")
                    candidates.append((f, n, path))
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:|#|<", target):
                    continue
                rel = target.split("#")[0]
                if not rel:
                    continue
                path = posixpath.normpath(posixpath.join(posixpath.dirname(f), rel))
                candidates.append((f, n, path))

    missing = [c for c in candidates if c[2] not in exists]
    if missing:
        ignored = set(subprocess.run(
            ["git", "-C", str(ROOT), "check-ignore", "--stdin"],
            input="\n".join(c[2] for c in missing), capture_output=True, text=True,
        ).stdout.splitlines())
        for f, n, path in missing:
            if path not in ignored:
                found[("paths", f)] += 1
                detail.append(f"paths  {f}:{n}: `{path}` does not exist")

    for entry in sorted(e for e in {f.split("/")[0] for f in tracked} if not e.startswith(".")):
        if entry not in ROOT_ENTRIES:
            found[("root", entry)] = 1
            detail.append(f"root   {entry}: not on the root list in .githooks/check-docs.py")

    return found, detail


def load_allow():
    allow = {}
    if ALLOW.exists():
        for raw in ALLOW.read_text().splitlines():
            line = raw.split("#")[0].strip()
            if line:
                check, f, count = line.split()
                allow[(check, f)] = int(count)
    return allow


def main():
    found, detail = findings()
    if "--baseline" in sys.argv:
        for (check, f), count in sorted(found.items()):
            print(f"{check} {f} {count}")
        return 0

    allow = load_allow()
    errors = []
    for key, count in sorted(found.items()):
        if count > allow.get(key, 0):
            errors.append(f"{key[0]} {key[1]}: {count} found, {allow.get(key, 0)} allowed")
    for key, count in sorted(allow.items()):
        now = found.get(key, 0)
        if key[0] == "lines":
            if now == 0:
                errors.append(f"lines {key[1]}: fits its cap now; delete its entry in {ALLOW.name}")
        elif now < count:
            errors.append(f"{key[0]} {key[1]}: {now} found, {count} allowed; lower the entry in {ALLOW.name}")

    if "-v" in sys.argv:
        print("\n".join(detail))
    if errors:
        print("check-docs: " + "\n  ".join(["failed:", *errors]), file=sys.stderr)
        print("  (run `python3 -I .githooks/check-docs.py -v` for every finding)", file=sys.stderr)
        return 1
    print(f"check-docs: ok ({sum(1 for _ in detail)} known findings allowed; -v lists them)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
