#!/usr/bin/env python3
"""Doc rules for the repo clean-up; only offenders missing from the allowlist fail.

Checks, over tracked Markdown files:

- paths:  a repo path in backticks, or a relative Markdown link, points at a
          tracked (or git-ignored) file or folder. Journal entries are exempt:
          they keep the paths of their day (agents/journal/README.md is not).
- dates:  no `YYYY-MM-DD` in table rows of the human pages (README.md,
          lab/inventory/, lab/systems/, apps/**/README.md). Dates belong in journal
          entries, which those pages link; a journal file name in a link
          does not count.
- lines:  length caps (notes pages, an app's NOTES.md or lab/systems/notes/, have
          none): AGENTS.md 40, app READMEs 40, journal entries 40
          (those dated from JOURNAL_CAP_FROM on),
          systems pages 150.
- rules:  each danger rule is spelled out only in its owner file, the root
          AGENTS.md and the README's first screen; elsewhere, a line naming
          it must point at the owner file on the same line or the next
          (a wrapped sentence).
- root:   the visible (not dot-) entries at the repo root are on a fixed list.
- moved:  a backticked path under a root folder that moved in the clean-up
          (MOVED) and that exists at its new place: the old spelling of a
          live path. The paths check misses these, since it only looks at
          paths whose first folder still exists. Journal entries are exempt.

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
    "AGENTS.md", "CLAUDE.md", "README.md", "mise.toml",
    "secret-scan.toml", "secret-scan.local.toml.example",
    "agents", "ansible", "apps", "iac",
    "lab",
}

# Root folders the clean-up moved, old -> new places. A path is flagged only
# when it exists at a new place, so another repo's `skills/...` is left alone.
MOVED = {
    "systems": ["lab/systems"], "inventory": ["lab/inventory"],
    "plans": ["agents/plans"], "ideas": ["agents/ideas"],
    "journal": ["agents/journal"], "skills": ["agents/skills"],
    "repo": ["agents/review", "agents/obsidian"], "bases": ["agents/obsidian/bases"],
    "decisions": ["agents/decisions", "agents/rules"],
}

# The 40-line cap applies to journal entries written after the clean-up; older
# entries are append-only and keep their length.
JOURNAL_CAP_FROM = "2026-11-20"
DATE = re.compile(r"\b20\d\d-\d\d-\d\d\b")
# A journal entry's file name starts with its date; a link to one is evidence, not a date.
JOURNAL_PATH = re.compile(r"agents/journal/20\d\d-\d\d-\d\d[\w.-]*")
BACKTICK = re.compile(r"`([^`\s]+)`")
LINK = re.compile(r"\]\(([^)\s]+)\)")

# Danger rules: (name, pattern, owner file, other files allowed to spell it out).
# Elsewhere a line may name the rule if it also points at the owner file;
# naming it with no pointer is a copy that drifts.
RULES = [
    ("base-snapshot", re.compile(r"base snapshot", re.I),
     "lab/systems/xcp-ng.md", {"AGENTS.md", "README.md"}),
    ("lan-cache", re.compile(r"LAN cache rule|every (new )?home VM downloads through", re.I),
     "ansible/README.md", {"AGENTS.md"}),
]


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True,
                          capture_output=True, text=True).stdout


def human_page(f):
    return (f == "README.md" or f.startswith("lab/inventory/")
            or posixpath.dirname(f) == "lab/systems"
            or (f.startswith("apps/") and f.endswith("/README.md")))


def journal_entry(f):
    """A dated journal entry; agents/journal/README.md is a living page, checked like others."""
    return f.startswith("agents/journal/") and f != "agents/journal/README.md"


def cap(f):
    if f == "AGENTS.md" or (f.startswith("apps/") and f.endswith("/README.md")):
        return 40
    if journal_entry(f) and posixpath.basename(f)[:10] >= JOURNAL_CAP_FROM:
        return 40
    if posixpath.dirname(f) == "lab/systems" and f != "lab/systems/README.md":
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
            cells = JOURNAL_PATH.sub("", line)
            if human_page(f) and line.startswith("|") and DATE.search(cells):
                found[("dates", f)] += 1
                detail.append(f"dates  {f}:{n}: {DATE.search(cells).group()}")
            for name, pat, owner, allowed in RULES:
                if (f != owner and f not in allowed and not journal_entry(f)
                        and pat.search(line)
                        and owner not in line + (lines[n] if n < len(lines) else "")):
                    found[("rules", f)] += 1
                    detail.append(f"rules  {f}:{n}: restates the {name} rule")
            if journal_entry(f):
                continue
            for tok in BACKTICK.findall(line):
                head, _, rest = tok.partition("/")
                rest = re.sub(r"(#.*|:\d+(-\d+)?)$", "", rest).rstrip("/")
                if head in MOVED and head not in tops and rest:
                    new = [f"{d}/{rest}" for d in MOVED[head] if f"{d}/{rest}" in exists]
                    if new:
                        found[("moved", f)] += 1
                        detail.append(f"moved  {f}:{n}: `{tok}` is now `{new[0]}`")
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
