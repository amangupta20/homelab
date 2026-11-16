#!/bin/sh
# Create Artifact Keeper's pull-through (remote) repositories and cap each one.
# Safe to run again: an existing repository is left as it is and only its cap is
# set again. The repository settings live here, so a rebuilt cache-1 gets them
# back from the repo instead of a backup (decisions/backup-tiers.md, rebuildable
# state).
#
# Usage: ./cache-remotes.sh [base URL]     default http://10.22.33.137
# Reads remotes.txt in this folder.
# Needs: bao (logged in), curl, jq.
#
# The repositories, their caps and the 80 GB budget are in remotes.txt next to
# this script. Each cap evicts the least recently used entries of its own
# repository; there is no cap across all of them.
set -eu
cd "$(dirname "$0")"

base=${1:-http://10.22.33.137}
GB=1000000000
remotes=$(grep -vE '^\s*(#|$)' remotes.txt)

total=$(echo "$remotes" | awk '{ sum += $3 } END { print sum }')
[ "$total" -le 80 ] || { echo "caps in remotes.txt add up to $total GB, over the 80 GB budget" >&2; exit 1; }

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
