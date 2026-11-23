# VPS apps

Compose stacks that Dokploy deploys on the remote VPS (`lab/systems/vps.md`).
This is the public-facing side: set up `secret-scan.local.toml` with your
domains before writing anything here (`agents/review/secret-scanning.md`).

| Folder | What it does |
|---|---|
| `openbao/` | the secret store (`lab/systems/openbao.md`) |
| `authentik/` | single sign-on for the lab |
| `langfuse/` | the AI reviewer's trace viewer |
| `hermes-webui/` | a public chat page for someone without lab access |
| `blinko/` | note-taking app, the test app for the shared Postgres |
| `pg-proxy/` | one address for the shared Postgres on the VPS |
| `pgadmin/`, `cloudbeaver/` | web UIs for the shared Postgres, tailnet only |
| `technitium/` | the home DNS cluster's secondary node and fallback resolver, tailnet only |
| `sablier/` | stops idle apps and starts them on the next request |

Each folder's README says its state and how you sign in. Only `hermes-webui/`
is known to deploy from this repo's `main`; how Dokploy pulls the rest is in
`agents/decisions/open-questions.md`. Apps still only on Dokploy move in later
(`agents/decisions/remote-vps-in-scope.md`, `lab/inventory/services.md`).
