# Extensions — harness-specific code

Only what cannot be a skill: code that hooks into one harness (a Pi extension,
a Hermes plugin, a Claude Code hook). One folder per harness:

```
agents/extensions/<harness>/<extension>/
```

Each extension has a short README: what it does, which harness version it was
tested with, and how that harness loads it (for Pi, a project link
`.pi/extensions -> ../agents/extensions/pi` added with the first one).

Prefer a skill. A skill works in every harness; an extension works in one, and
breaks when that harness changes.

None yet.
