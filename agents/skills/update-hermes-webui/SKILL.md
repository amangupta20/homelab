---
name: update-hermes-webui
description: Use when checking for or applying an update to the second Hermes WebUI on the VPS (apps/vps/hermes-webui/) — reads the newest WebUI and Hermes Agent releases, their known issues and open bug reports, picks a safe release pair, and if asked bumps both pins, deploys through Dokploy and verifies. The check half is read-only and safe to run on a schedule.
---

# Update the second Hermes WebUI

**Status:** UNTESTED as written. Every step was done by hand once on 2026-11-21
(the journal entry of that day, `update-hermes-webui`), and this skill was written from that work.
**Touches:** read-only (part A) | writes to the Dokploy service of `apps/vps/hermes-webui/` (part B)

## When to use / when not to

- Part A, **check**: on a timer, or when someone asks "is Hermes up to date?". It only reads,
  and ends in a report.
- Part B, **apply**: only after a person has read part A's report and said yes. It restarts the
  chat for whoever uses it, so do not run it on a timer.
- Not for the owner's own Hermes stack (a different Dokploy service, not in this repo).

How the stack updates (`apps/vps/hermes-webui/compose.yaml`): the WebUI image has no agent, and it
runs the one in `~/.hermes/hermes-agent` in its home volume. A one-shot `agent-src` service copies
the agent from the pinned `nousresearch/hermes-agent` image into the volume on deploy. It copies only
when that image's `install-stamp.json` differs from the one already in the volume. So an update
means changing two pinned tags and deploying. A rollback means reverting them.

## Part A — check (read-only)

1. **Current pins.**
   `grep -nE 'image: (ghcr.io/nesquena/hermes-webui|nousresearch/hermes-agent):' apps/vps/hermes-webui/compose.yaml`
   Also read the comment above the agent pin. It names the issues that held the agent back last time.
2. **Newest stable releases.** Never use the pre-releases (`exp-v*`, `+canary`):
   ```bash
   gh release list -R nesquena/hermes-webui --exclude-pre-releases -L 3
   gh release list -R NousResearch/hermes-agent --exclude-pre-releases -L 3
   ```
3. **Read the WebUI release's "Known issues" first.** It often already names the agent versions that
   break something:
   ```bash
   gh release view <webui tag> -R nesquena/hermes-webui --json body -q .body \
     | awk '/^## Known issues/{f=1;next} /^## /{f=0} f'
   ```
   On 2026-11-21 that section said agent v0.23.3 cannot delete sessions (#9213), while v0.23.2 and
   earlier can.
4. **Issues opened since the release.** A release a few hours old may have regressions that are
   already reported:
   ```bash
   gh issue list -R nesquena/hermes-webui --state open --search "created:>=<release date>" -L 40
   gh issue list -R NousResearch/hermes-agent --state open --search "<agent tag> in:title" -L 20
   ```
   Most agent issues are for the desktop app, Telegram or the TUI (text interface), and do not apply
   here. Look for ones that do. This instance runs the agent inside the WebUI (no gateway), signs in
   by OIDC (OpenID Connect) or password, and uses a `custom` OpenAI-compatible provider with
   `reasoning_effort: high`. Read it with
   `grep -nE '^(model|  provider|  base_url|  default)|reasoning' ~/.hermes/config.yaml`
   inside the container, and check it again if it may have changed.
5. **Re-check each issue that held a pin back** (named in the compose comment):
   `gh issue view <n> -R <repo> --json state` and, for its fix PR, `gh pr view <n> -R <repo> --json state,mergeCommit`.
   A merged fix is in a release only if the release's tag contains the merge commit:
   `gh api repos/<repo>/compare/<tag>...<merge commit> -q .status` prints `behind` or `identical`
   when it does, and `ahead` when it does not.
6. **Pick the pair.** Use the newest WebUI stable release. Use the newest agent stable release that
   none of steps 3–5 rules out. An older agent is fine: the WebUI supports a range. If nothing is
   newer than the pins, report "up to date" and stop.
7. **Both images exist for arm64** (the VPS is an Ampere ARM machine):
   ```bash
   docker manifest inspect ghcr.io/nesquena/hermes-webui:<version without v> | grep -o '"architecture": "[a-z0-9]*"' | sort -u
   docker manifest inspect nousresearch/hermes-agent:<agent tag> | grep -o '"architecture": "[a-z0-9]*"' | sort -u
   ```
   The WebUI's registry tags have no `v` (`0.52.723`). The agent's tags keep it (`v0.23.1`).
8. **Report:** the current pair, the proposed pair, and each issue that decided it, with its link.
   Name each newer release you are skipping and say why. Say whether a person needs to approve
   part B.

## Part B — apply (writes; a person said yes to part A's pair)

### Before you start

Back up both volumes to the workstation with the container stopped. Leave out `hermes-agent/`,
because it can be rebuilt from the agent image. Check the `state.db` modification time first, so you
do not stop someone mid-chat.

```bash
ssh <vps> 'sudo docker exec <appName>-hermes-webui-1 ls -la /home/hermeswebui/.hermes/state.db'
ssh <vps> 'sudo docker stop -t 30 <appName>-hermes-webui-1'
B=~/backups/hermes-webui-1-pre-update-<date>; mkdir -p $B
for v in home workspace; do
  ssh <vps> "sudo tar -C /var/lib/docker/volumes/<appName>_hermes-webui-$v/_data --exclude=./hermes-agent -czf - ." > $B/hermes-webui-$v.tgz
  tar -tzf $B/hermes-webui-$v.tgz | wc -l   # equals the count below
  ssh <vps> "sudo sh -c 'cd /var/lib/docker/volumes/<appName>_hermes-webui-$v/_data && find . -path ./hermes-agent -prune -o -print | wc -l'"
done
```

`<appName>` is the Dokploy service's app name (`compose.one`, below). This is not the stack's real
backup, which is still to do (`apps/vps/hermes-webui/README.md`).

### Steps

1. **Branch and bump.** In `apps/vps/hermes-webui/compose.yaml`, change both tags. Rewrite the
   comment above the agent pin so it names the issues that hold it back now. Then:
   `cd apps/vps/hermes-webui && docker compose --env-file .env.example config >/dev/null` — expect:
   no output. Commit, then push the branch.
2. **Deploy that branch with Dokploy's API.** The key is in OpenBao (`kv/general/dokploy`, field
   `api_key`). The API is on the Dokploy host, port 3000, over the tailnet. Find the service with
   `GET /api/project.all`, then `GET /api/compose.one?composeId=<id>` for the one whose `composePath`
   is `./apps/vps/hermes-webui/compose.yaml`.
   ```bash
   curl -s -X POST -H "x-api-key: $K" -H 'content-type: application/json' "$A/compose.update" \
     -d '{"composeId":"<id>","customGitBranch":"<branch>","autoDeploy":false}'
   curl -s -X POST -H "x-api-key: $K" -H 'content-type: application/json' "$A/compose.deploy" \
     -d '{"composeId":"<id>","title":"<pair> (branch <branch>)"}'
   ```
   Expect `Deployment queued`. Keep `autoDeploy` false. An update should happen when someone chooses,
   not on any push to `main` (owner, 2026-11-21).
3. **Watch it start.** `sudo docker ps -a | grep <appName>`. Expect `agent-src` to show `Exited (0)`
   and its log to say `agent copied: {... "displayVersion": "<agent>" ...}`. Then the WebUI starts
   and rebuilds its venv, which took about 2 minutes on 2026-11-21. It shows `unhealthy` until it
   listens.

### Verify

- WebUI log, in this order: `Applying hermes-agent's [tool.uv] override-dependencies`,
  `Resolved ~100 packages` (not `No solution found`), `Hermes agent critical imports verified`,
  agent dir `[ok]`, `Hermes Web UI listening on http://0.0.0.0:8787`. Then the container shows
  `(healthy)` with `RestartCount` 0.
- `sudo docker exec -u hermeswebui -e HOME=/home/hermeswebui <container> /app/venv/bin/hermes --version`
  prints the new agent version.
- No `hermes-agent.new` folder is left in the volume.
- The session count has not changed. The `sessions` table in `~/.hermes/state.db`, read-only, with
  the venv's Python.
- Still locked: `GET /api/auth/status` shows `auth_enabled: true` with the same OIDC and password
  flags as before. From outside, `https://<domain>/` answers 302 to `/login`, and `/api/sessions`
  answers 401.
- A person sends one chat message that uses a tool and gets an answer. That checks the provider,
  which no command above does.

### Stop if

- `agent-src` exits non-zero, or the WebUI log says `No solution found` or `missing modules`, or the
  container restarts. Roll back: revert the commit, push, deploy the branch again. `agent-src` then
  copies the old agent back, because its stamp differs. If state looks wrong, restore the tars.
- A check above fails, and the cause is not in the "Known issues" you already read.

### Afterwards

- Open the pull request with the report from part A. After the merge, set the service's branch back
  to `main` (`compose.update`, `customGitBranch: "main"`). No new deploy is needed: `main` now holds
  what is deployed.
- Update `apps/vps/hermes-webui/NOTES.md` ("Derived from", "Dates") and write
  a journal entry, `agents/journal/<date>-update-hermes-webui.md`.

## Gotchas

- The WebUI's own "Update" buttons do not apply here. The image is pinned and the agent comes from
  `agent-src`.
- `latest` and `experimental` move without warning. Pin numbered tags only.
- The newest agent is not automatically the right one. On 2026-11-21 the two newest (v0.23.2, v0.23.3)
  both had bugs that could hit this instance, so v0.23.1 was pinned.
