# The Obsidian view

The repo doubles as an Obsidian vault. Obsidian is a desktop notes app that
reads a folder of markdown files; it adds live tables, a graph of links and
nicer rendering on top of the same files. Nothing here depends on it: GitHub,
agents and plain editors read the files as before. The owner reads the repo
in Obsidian and does not write in it; agents keep it current.

## Open it

Obsidian → Open folder as vault → this checkout. Start at `agents/obsidian/Home.md`.

- Settings → Files and links → turn **Use [[Wikilinks]]** off, so a link
  Obsidian inserts stays a normal relative link GitHub and agents can follow.
- Obsidian writes its own settings to a local .obsidian folder, which `.gitignore` keeps out
  of the repo. They are per person; never commit them.

Tested 2026-10-28 by the owner: the vault opened, `Home.md` and the tables
rendered.

## What makes it work

| Piece | Where | What it does |
|---|---|---|
| Page properties | the YAML block at the top of every page in `lab/systems/`, `lab/inventory/`, `agents/plans/`, `agents/ideas/` | the data the tables are built from |
| Tables | `agents/obsidian/bases/*.base` ([Obsidian Bases](https://obsidian.md/help/bases/syntax)) | one file per table; each defines its filters and views |
| Front page | `agents/obsidian/Home.md` | links to every area and embeds the tables with `![[agents/obsidian/bases/<name>.base]]` |
| Callouts | `> [!WARNING]`, `> [!NOTE]`, `> [!IMPORTANT]` | boxed warnings that render in Obsidian and on GitHub |
| Diagram | Mermaid block in `lab/inventory/network.md` | renders in Obsidian and on GitHub |
| Check | `.githooks/check-properties.py` | fails a commit (pre-commit hook) or CI when properties are missing or wrong |

`agents/obsidian/Home.md` is the Obsidian front page; `README.md` stays the GitHub front page.
On GitHub, `agents/obsidian/Home.md`'s embeds show as plain `![[...]]` text — expected.

## Page properties

```yaml
---
type: system            # system | inventory | plan | idea; READMEs: system-index, inventory-index, plan-index, idea-index
tags:
  - system
  - vps
---
```

Only `type` and `tags`. Until 2026-11-19 the block also carried `status`,
`verified` and `hosts`; the owner cut them (repo clean-up, decision B)
because they restated the page body and drifted from it. A page's status
lives in its body's Status line, its sources in its Source line or table.
The check rejects any other key, so a new property means changing the check
and this page in the same commit.

### Rules

- **Properties never add a fact.** `type` says which folder template the
  page follows; `tags` are for finding pages in Obsidian.
- **New page in `lab/systems/`, `lab/inventory/`, `agents/plans/` or `agents/ideas/`:** copy the
  template from that folder's README; it includes the property block.
- **Links stay relative markdown links** (`[text](../../lab/systems/xcp-ng.md)`), never
  `[[wikilinks]]`, so GitHub and agents keep working. The one exception is
  `agents/obsidian/Home.md`'s `![[agents/obsidian/bases/...]]` embeds, which only Obsidian needs.
- **A new table** goes in `agents/obsidian/bases/` and is embedded from
  `agents/obsidian/Home.md`; do not paste
  table definitions into pages, or two copies drift.

Run the check by hand: `mise run check:properties`.

## What it does not catch

The check sees a missing, misspelled or unknown property, a wrong `type`
for the folder, and an embed in `agents/obsidian/Home.md` whose table file does not exist.
Whether the tags are useful is on whoever edits the page.
