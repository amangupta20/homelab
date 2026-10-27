# VPS apps

Stacks deployed on the remote VPS by Dokploy: `openbao/`, and `hermes-webui/`
(see its README for state). `hermes-webui/` is deployed from this repo's
`main`, verified 2026-10-27; how Dokploy pulls each of the rest is still
`decisions/open-questions.md`'s. The apps already on Dokploy move in later
(`decisions/remote-vps-in-scope.md`, `inventory/services.md`), and OpenBao's
part is `systems/openbao.md`'s. This is the public-facing side: set up
`secret-scan.local.toml` with your domains before writing anything here
(`repo/secret-scanning.md`).
