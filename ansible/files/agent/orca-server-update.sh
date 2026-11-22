#!/bin/bash
# Keeps the Orca server on agent-1 on Orca's latest release, so it stays in step with the owner's desktop and
# phone, which update themselves. Installed by ansible/agent.yml ("Orca server"), run by orca-server-update.timer.
#
# Orca cannot do this itself on Linux: a headless server reports `manual-service-update-required`, and paired
# clients can update a server only on macOS (hasServeUpdateSupervisor in src/main/updater/serve-update-handoff.ts,
# stablyai/orca, 2026-11-22). Orca's docs: "stop the server, replace /opt/orca-server with a newer release, and
# start it again" (docs/site/content/docs/remote-servers.mdx, "Install only the server on Linux").
#
# Each release goes in its own folder, /opt/orca-server/<version>; /opt/orca-server/current points at the one in
# use and is what the service starts. To go back a release: point `current` at the older folder and restart
# orca-serve.service as the owner's user.
set -euo pipefail

root=/opt/orca-server
user=aman
uid=$(id -u "$user")
cache=http://10.22.33.137/general/github-releases/stablyai/orca/releases/download
asset=orca-server-linux-x64.tar.gz

as_user() { runuser -u "$user" -- env XDG_RUNTIME_DIR="/run/user/$uid" "$@"; }

# Only the version comes from GitHub (the "latest" redirect); the files come through the LAN cache.
latest=$(curl -fsSI --max-time 60 https://github.com/stablyai/orca/releases/latest |
  sed -n 's|^location: .*/tag/v\([0-9][0-9.]*\)\r*$|\1|ip')
if [ -z "$latest" ]; then
  echo "Could not read Orca's latest release from GitHub." >&2
  exit 1
fi
current=$(basename "$(readlink -f "$root/current")")
if [ "$latest" = "$current" ]; then
  echo "Orca server $current is the latest release."
  exit 0
fi
if [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)" != "$latest" ]; then
  echo "GitHub's latest release ($latest) is older than the installed $current; leaving it." >&2
  exit 0
fi

if [ ! -x "$root/$latest/bin/orca-ide" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  # A release the cache has not seen yet comes in slowly on its first fetch (68 MB took 10 minutes, 2026-11-22).
  curl -fsSL --max-time 300 -o "$tmp/orca-server-sha256sums.txt" "$cache/v$latest/orca-server-sha256sums.txt"
  curl -fsSL --max-time 3000 -o "$tmp/$asset" "$cache/v$latest/$asset"
  grep -q " $asset\$" "$tmp/orca-server-sha256sums.txt"
  (cd "$tmp" && sha256sum --check --ignore-missing --strict --quiet orca-server-sha256sums.txt)
  mkdir "$tmp/unpacked"
  tar -xzf "$tmp/$asset" -C "$tmp/unpacked" --strip-components=1
  if [ "$("$tmp/unpacked/bin/orca-ide" --version)" != "$latest" ]; then
    echo "The $latest archive reports a different version; not installing it." >&2
    exit 1
  fi
  mv "$tmp/unpacked" "$root/$latest"
fi

# Restart only when no terminal is open, so a running agent is never cut off; the next run tries again.
# Terminals live in a separate terminal host that survives a server restart (remote-servers.mdx), but a new
# release may replace that too.
if terminals=$(as_user "$root/current/bin/orca-ide" terminal list --json 2>/dev/null); then
  count=$(jq '.result.terminals | length' <<<"$terminals")
  if [ "$count" != 0 ]; then
    echo "Orca server $latest is ready, but $count terminal(s) are open; trying again on the next run."
    exit 0
  fi
fi

ln -sfn "$latest" "$root/current.new"
mv -T "$root/current.new" "$root/current"
as_user systemctl --user restart orca-serve.service
echo "Orca server updated from $current to $latest."

# Keep the release just replaced, for going back; remove older ones.
for dir in "$root"/[0-9]*; do
  case "$(basename "$dir")" in
    "$latest" | "$current") ;;
    *) rm -rf "$dir" ;;
  esac
done
