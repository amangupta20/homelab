#!/bin/bash
# docker-cleanup: Dokploy schedule of type dokploy-server, daily 05:20 IST. Replaces Dokploy's own
# "Daily Docker Cleanup", which must stay off: it removes every stopped container, and an app that
# Sablier has put to sleep is a stopped container (journal/2026-11-13-cleanup-removed-sleeping-apps.md).
set -u

# Stopped containers, except the ones Sablier may start again.
docker container prune --force --filter "label!=sablier.enable=true"

# Images no container uses. A sleeping app's container still exists, so its image stays.
docker image prune --all --force

docker builder prune --all --force

# No `docker system prune` and no network or volume prune: a sleeping app's networks and volumes
# must be there when it wakes. No `docker system df` either: it did not return within 7 minutes
# on this host (tried 2026-11-13).
