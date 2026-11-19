# 2026-11-13 — Dokploy's Docker cleanup removed the sleeping apps

**Who:** the owner, with Claude Code  **Scope:** Dokploy on the Remote VPS; projects `blinko`, `pgadmin`, `cloudbeaver`, `langfuse`  **Mode:** write
**Task:** the owner found the apps behind Sablier gone from their stacks and answering 404  **Skill:** none

## What was found

- No container labelled `sablier.enable=true` existed (`docker ps -a`). The named volumes of all four apps were still there
  (`docker volume ls`); their images were not (`docker images`).
- Sablier's log has "instance removed from group … reason=removed" at 23:50:00 UTC on 2026-11-08, -09, -10 and -12. Dokploy's log has
  "Running docker cleanup" at 23:50:00 UTC every day (05:20 IST). The cleanup removes stopped containers, and Sablier's `stop` strategy
  leaves a sleeping app as one. Last night it removed Blinko and Langfuse's four containers; pgAdmin and CloudBeaver went on earlier
  nights.

## What changed

- Dokploy's daily Docker cleanup turned off (`settings.updateDockerCleanup`, `enableDockerCleanup` false).
- Blinko, pgAdmin, CloudBeaver and Langfuse redeployed (`compose.deploy`), unchanged.
- New Dokploy schedule `docker-cleanup`, daily 05:20 IST, running `apps/vps/sablier/host/dokploy-schedule-docker-cleanup.sh`: it
  prunes stopped containers except Sablier's, unused images and the build cache (`apps/vps/sablier/README.md`).

## Snapshot / backup taken

None: the redeploys recreated containers on their existing volumes, and the other two changes are settings.

## How it was verified

- `settings.getWebServerSettings` reads `enableDockerCleanup` false.
- After the redeploys all seven containers were healthy, and each app's front page answered over HTTPS: Blinko, CloudBeaver and
  Langfuse 200, pgAdmin 302 to its login page.
- The new schedule, run by hand with Blinko, pgAdmin and CloudBeaver asleep and a throwaway container in state `Created`: the
  throwaway was removed and the three sleeping containers stayed. CloudBeaver and Blinko then woke in 11.6 s each.
- A first version of the script ended with `docker system df`, which had not returned after 7 minutes; the line was removed.

## Still open

- One wake of CloudBeaver, right after its redeploy, answered 502 after 25.7 s although Sablier logged the instance ready. Two later
  wakes answered in 11.5 s. Cause not found.
- The schedule's first run at its own time (05:20 IST, 2026-11-14) has not been seen yet.
- Dokploy was updated during this session, before the setting was changed; whether an update turns the cleanup back on is unknown.
  Check the setting after the next update.
