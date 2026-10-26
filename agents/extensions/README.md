# Extensions — harness-specific code

Only what cannot be a skill: code that hooks into one harness (a Pi extension,
a Hermes plugin, a Claude Code hook). One folder per harness:

```
agents/extensions/<harness>/<extension>/
```

Each extension has a short README: what it does, which harness version it was
tested with, and how that harness loads it.

Planned, not done: for Pi, the first extension would add a project link from
.pi/extensions to agents/extensions/pi. Pi 1.4.0 `docs/configuration.md`
lists .pi/extensions as the project extensions folder; untested here.

Prefer a skill. A skill can work in any harness that reads the shared skills
folder; an extension is tied to one harness and breaks when that harness
changes.

None yet.
