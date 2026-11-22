#!/bin/bash
# Installs the Antigravity CLI (agy) on agent-1 and keeps it on Google's latest release. Installed by
# ansible/agent.yml ("Antigravity CLI"), which runs it once; agy-update.timer runs it daily after that.
#
# Google's installer (https://antigravity.google/cli/install.sh, read 2026-11-22) reads a manifest for the
# platform, downloads the archive it names from storage.googleapis.com and checks its SHA-512; agy then
# updates itself from the same place. This does the same through the LAN cache (`antigravity` in
# apps/homeserver/artifact-keeper/remotes.txt). agy's own updater is off (AGY_CLI_DISABLE_AUTO_UPDATE, set by
# agent.yml), and it could not write to /usr/local/bin anyway.
set -euo pipefail

manifest_url=https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
upstream=https://storage.googleapis.com/antigravity-public/
cache=http://10.22.33.137/general/antigravity/
dest=/usr/local/bin/agy

# Only the manifest (version, file, digest) comes from Google; the archive comes through the cache.
manifest=$(curl -fsSL --max-time 60 "$manifest_url")
version=$(jq -er .version <<<"$manifest")
url=$(jq -er .url <<<"$manifest")
sha512=$(jq -er .sha512 <<<"$manifest")
case "$url" in
  "$upstream"*) ;;
  *) echo "The manifest names $url, outside $upstream; not installing it." >&2; exit 1 ;;
esac

installed=$("$dest" --version 2>/dev/null || true)
if [ "$installed" = "$version" ]; then
  echo "agy $installed is the latest release."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --max-time 1800 -o "$tmp/agy.tar.gz" "$cache${url#"$upstream"}"
echo "$sha512  $tmp/agy.tar.gz" | sha512sum --check --quiet --strict
tar -xzf "$tmp/agy.tar.gz" -C "$tmp" antigravity
if [ "$("$tmp/antigravity" --version)" != "$version" ]; then
  echo "The $version archive reports a different version; not installing it." >&2
  exit 1
fi
# A rename, so a running agy keeps its old file until it exits.
install -m 0755 "$tmp/antigravity" "$dest.new"
mv "$dest.new" "$dest"
echo "agy updated from ${installed:-nothing} to $version."
