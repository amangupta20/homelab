# The Obsidian view

The repo doubles as an Obsidian vault. Obsidian is a desktop notes app that
reads a folder of markdown files; it adds live tables, a graph of links and
nicer rendering on top of the same files. Nothing here depends on it: GitHub,
agents and plain editors read the files as before. The owner reads the repo
in Obsidian and does not write in it; agents keep it current.

## Open it

Obsidian → Open folder as vault → this checkout. Start at `Home.md`.

- Settings → Files and links → turn **Use [[Wikilinks]]** off, so a link
  Obsidian inserts stays a normal relative link GitHub and agents can follow.
- Obsidian writes its own settings to a local .obsidian folder, which `.gitignore` keeps out
  of the repo. They are per person; never commit them.

Tested 2026-10-28 by the owner: the vault opened, `Home.md` and the tables
rendered.

## What makes it work

| Piece | Where | What it does |
|---|---|---|
| Page properties | the YAML block at the top of every page in `systems/`, `inventory/`, `plans/`, `ideas/` | the data the tables are built from |
| Tables | `bases/*.base` ([Obsidian Bases](https://obsidian.md/help/bases/syntax)) | one file per table; each defines its filters and views |
| Front page | `Home.md` | links to every area and embeds the tables with `![[bases/<name>.base]]` |
| Callouts | `> [!WARNING]`, `> [!NOTE]`, `> [!IMPORTANT]` | boxed warnings that render in Obsidian and on GitHub |
| Diagram | Mermaid block in `inventory/network.md` | renders in Obsidian and on GitHub |
| Check | `.githooks/check-properties.py` | fails a commit (pre-commit hook) or CI when properties are missing or wrong |

`Home.md` is the Obsidian front page; `README.md` stays the GitHub front page.
On GitHub, `Home.md`'s embeds show as plain `![[...]]` text — expected.

## Page properties

```yaml
---
type: system            # system | inventory | plan | idea; READMEs: system-index, inventory-index, plan-index, idea-index
status: "running"       # the page's own Status line, shortened
verified: "yes (recon 2026-10-26 over SSH)"   # yes / no / partially, and how — from the page's Source/State lines
hosts:                  # optional; exact host names from inventory/hosts.md
  - Remote VPS
tags:
  - system
  - vps
---
```

Folder READMEs carry only `type` and `tags`. No other keys: the check
rejects them, so a new property means changing the check and this page in
the same commit.

### Rules

- **Properties summarise the page; they never add a fact.** Every value must
  already be stated in the page body (its Status line, Source line or text).
  An agent that cannot find it in the body writes `unknown`.
- **Change both in one commit.** When a page's Status line, verification or
  host changes, its properties change in the same commit. The owner files
  still win: if a property disagrees with the body or with
  `inventory/hosts.md` / `inventory/services.md`, the property is wrong.
- **`hosts` must match `inventory/hosts.md` exactly.** The check enforces it.
  A renamed host is renamed in its properties in the same commit.
- **New page in `systems/`, `inventory/`, `plans/` or `ideas/`:** copy the template from
  that folder's README; it includes the property block.
- **Links stay relative markdown links** (`[text](path.md)`), never
  `[[wikilinks]]`, so GitHub and agents keep working. The one exception is
  `Home.md`'s `![[bases/...]]` embeds, which only Obsidian needs.
- **A new table** goes in `bases/` and is embedded from `Home.md`; do not paste
  table definitions into pages, or two copies drift.

Run the check by hand: `mise run check:properties`.

## What it does not catch

The check sees a missing, misspelled or unknown property and a host that does
not exist. It cannot tell whether `status` still matches the page's Status
line; that is on whoever edits the page, and on the reviewer
(`repo/review.md`).
