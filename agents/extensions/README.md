# Extensions — harness-specific code

Only what cannot be a skill: code that hooks into one harness (a Pi extension,
a Hermes plugin, a Claude Code hook). One folder per harness:

```
agents/extensions/<harness>/<extension>/
```

Each extension has a short README: what it does, which harness version it was
tested with, and how that harness loads it. For Pi, the first extension adds
a project link from .pi/extensions to agents/extensions/pi, since Pi loads
project extensions from .pi/extensions.

Prefer a skill. A skill can work in any harness that reads the shared skills
folder; an extension is tied to one harness and breaks when that harness
changes.

None yet.
