#!/bin/sh
# Create Artifact Keeper's pull-through (remote) repositories, cap each one, and
# keep one idle rule assigned to all of them. Safe to run again: an existing
# repository is left as it is and only its cap is set again; the rule is
# created once and then updated in place. The repository settings live here, so a rebuilt cache-1 gets them
# back from the repo instead of a backup (decisions/backup-tiers.md, rebuildable
# state).
#
# Usage: ./cache-remotes.sh [base URL]     default http://10.22.33.137
# Reads remotes.txt in this folder.
# Needs: bao (logged in), curl, jq.
#
# The repositories and their caps are in remotes.txt next to this script. Each
# cap evicts the least recently used entries of its own repository. The caps may
# add up to more than the disk: the instance-wide ceiling (STORAGE_QUOTA_BYTES in
# compose.yaml) is the hard limit, and at it the cache serves without storing.
# The idle rule deletes entries not fetched for IDLE_DAYS days, so the cache
# drains even when no single repository reaches its own cap.
set -eu
cd "$(dirname "$0")"

base=${1:-http://10.22.33.137}
GB=1000000000
IDLE_DAYS=30
POLICY=cache-idle
remotes=$(grep -vE '^\s*(#|$)' remotes.txt)

ceiling=$(sed -n 's/^ *STORAGE_QUOTA_BYTES: *"\{0,1\}\([0-9]*\)"\{0,1\}.*/\1/p' compose.yaml)
[ -n "$ceiling" ] || { echo "no STORAGE_QUOTA_BYTES in compose.yaml" >&2; exit 1; }
over=$(echo "$remotes" | awk -v c="$ceiling" -v g="$GB" '$3 * g > c { print $1 }')
[ -z "$over" ] || { echo "caps over the $((ceiling / GB)) GB ceiling: $over" >&2; exit 1; }

password=$(bao kv get -mount=kv -field=admin_password homelab/artifact-keeper)
token=$(jq -nc --arg p "$password" '{username: "admin", password: $p}' |
  curl -sf -H 'Content-Type: application/json' --data @- "$base/api/v1/auth/login" |
  jq -r .access_token)
[ -n "$token" ] && [ "$token" != null ] || { echo "login failed" >&2; exit 1; }

# api METHOD PATH [curl args]: prints the HTTP status; on a failure also the
# body, and returns 1 so the script stops.
api() {
  method=$1 path=$2
  shift 2
  out=$(curl -s -w '\n%{http_code}' -X "$method" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' "$@" "$base/api/v1/$path")
  code=$(printf '%s\n' "$out" | tail -n 1)
  case $code in
    2*) echo "$code" ;;
    *) echo "$code $(printf '%s\n' "$out" | sed '$d')" >&2; return 1 ;;
  esac
}

echo "$remotes" | while read -r key format cap url; do
  [ -n "$key" ] || continue
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" \
    "$base/api/v1/repositories/$key")
  if [ "$code" = 404 ]; then
    body=$(jq -nc --arg k "$key" --arg f "$format" --arg u "$url" \
      '{key: $k, name: $k, format: $f, repo_type: "remote", visibility: "public", upstream_url: $u}')
    r=$(api POST repositories -d "$body")
    echo "$key: created ($r)"
  else
    echo "$key: exists ($code)"
  fi
  r=$(api PUT "repositories/$key/proxy-cache-cap" -d "{\"cap_bytes\": $((cap * GB))}")
  echo "$key: cap $cap GB ($r)"
done

# The idle rule: one no_downloads_days policy assigned to every remote above. It
# goes by when an entry was last served, not when it was cached. A global
# (applies_to_all) policy would not reach a remote's cache, so it is assigned
# explicitly. It runs every 6 hours (the backend's default cadence).
ids=$(echo "$remotes" | while read -r key _; do
  curl -sf -H "Authorization: Bearer $token" "$base/api/v1/repositories/$key" | jq -r .id
done | jq -Rsc 'split("\n") | map(select(length > 0))')
rule=$(jq -nc --arg n "$POLICY" --argjson d "$IDLE_DAYS" --argjson ids "$ids" \
  '{name: $n, policy_type: "no_downloads_days", config: {days: $d}, repository_ids: $ids,
    description: "Cache entries not fetched for this many days (cache-remotes.sh)", enabled: true}')
policy=$(curl -sf -H "Authorization: Bearer $token" "$base/api/v1/admin/lifecycle" |
  jq -r --arg n "$POLICY" '.[] | select(.name == $n) | .id')
if [ -z "$policy" ]; then
  r=$(api POST admin/lifecycle -d "$rule")
  echo "$POLICY: created, $IDLE_DAYS days on $(echo "$ids" | jq length) repositories ($r)"
else
  r=$(api PATCH "admin/lifecycle/$policy" -d "$(echo "$rule" | jq -c 'del(.policy_type)')")
  echo "$POLICY: updated, $IDLE_DAYS days on $(echo "$ids" | jq length) repositories ($r)"
fi
