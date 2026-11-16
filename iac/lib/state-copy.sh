# Second copy of an OpenTofu root's state, in Garage at home.
#
# Sourced by each root's run.sh. The primary state is the encrypted object in
# Backblaze B2; this copies that object as it is, never `tofu state pull`, which
# prints decrypted state. Copies are timestamped (<root>/<UTC time>.tfstate) and
# the newest 14 are kept, so a corrupted state cannot overwrite the good copy.
#
# Needs: bao (logged in), rclone, and read access to kv/general/tofub2 and
# kv/general/tofugarage. Credentials go to rclone through environment variables
# in a subshell; nothing is written to disk.
#
# Garage is the secondary copy, so it never blocks OpenTofu (owner, 2026-11-16).
# run.sh calls state_sync after every command and ignores its result: when the
# newest Garage copy already matches B2 it does nothing, and when Garage was down
# at the last change, the next run of any command catches up. `./run.sh backup`
# runs the same sync and exits 1 if it fails.

STATE_COPY_KEEP=14

# state_sync <key of the state object in B2, e.g. oci/terraform.tfstate>
state_sync() (
  set -eu
  key=$1
  root=${key%%/*}
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  rc_opts="--contimeout 5s --timeout 60s --retries 1 --low-level-retries 2"

  b2() { bao kv get -mount=kv -field="$1" general/tofub2; }
  garage() { bao kv get -mount=kv -field="$1" general/tofugarage; }

  RCLONE_CONFIG_B2_TYPE=b2
  RCLONE_CONFIG_B2_ACCOUNT=$(b2 keyID)
  RCLONE_CONFIG_B2_KEY=$(b2 applicationKey)
  RCLONE_CONFIG_GARAGE_TYPE=s3
  RCLONE_CONFIG_GARAGE_PROVIDER=Other
  RCLONE_CONFIG_GARAGE_ENDPOINT=$(garage endpoint_url)
  RCLONE_CONFIG_GARAGE_REGION=$(garage region)
  RCLONE_CONFIG_GARAGE_ACCESS_KEY_ID=$(garage key_id)
  RCLONE_CONFIG_GARAGE_SECRET_ACCESS_KEY=$(garage access_key)
  RCLONE_CONFIG_GARAGE_FORCE_PATH_STYLE=true
  # The key is limited to one existing bucket and cannot create buckets.
  RCLONE_CONFIG_GARAGE_NO_CHECK_BUCKET=true
  export RCLONE_CONFIG_B2_TYPE RCLONE_CONFIG_B2_ACCOUNT RCLONE_CONFIG_B2_KEY \
    RCLONE_CONFIG_GARAGE_TYPE RCLONE_CONFIG_GARAGE_PROVIDER \
    RCLONE_CONFIG_GARAGE_ENDPOINT RCLONE_CONFIG_GARAGE_REGION \
    RCLONE_CONFIG_GARAGE_ACCESS_KEY_ID RCLONE_CONFIG_GARAGE_SECRET_ACCESS_KEY \
    RCLONE_CONFIG_GARAGE_FORCE_PATH_STYLE RCLONE_CONFIG_GARAGE_NO_CHECK_BUCKET

  src="b2:$(b2 bucket_name)/$key"
  dir="garage:$(garage bucketname)/$root"
  dst="$dir/$stamp.tfstate"

  # shellcheck disable=SC2086 # rc_opts is a list of flags
  if ! rclone lsf $rc_opts "$src" 2>/dev/null | grep -q .; then
    return 0 # nothing in B2 yet: this root has no state
  fi
  # shellcheck disable=SC2086
  if ! listing=$(rclone lsf $rc_opts --files-only "$dir" 2>/dev/null); then
    echo "WARNING: Garage unreachable; the state copy catches up on the next run" >&2
    return 1
  fi

  # rclone cannot compare hashes across the two (B2 keeps SHA-1, Garage MD5),
  # so compare the bytes themselves. State files are small.
  want=$(rclone cat "$src" | sha256sum | cut -d' ' -f1)
  newest=$(printf '%s\n' "$listing" | sort | tail -n 1)
  if [ -n "$newest" ] &&
    [ "$(rclone cat "$dir/$newest" | sha256sum | cut -d' ' -f1)" = "$want" ]; then
    return 0 # already in sync
  fi

  # shellcheck disable=SC2086
  if ! rclone copyto $rc_opts -q "$src" "$dst" ||
    [ "$(rclone cat "$dst" | sha256sum | cut -d' ' -f1)" != "$want" ]; then
    echo "WARNING: state copy to Garage failed; it catches up on the next run" >&2
    return 1
  fi

  printf '%s\n' "$listing" "$stamp.tfstate" | grep . | sort | head -n "-$STATE_COPY_KEEP" |
    while read -r old; do rclone deletefile -q "$dir/$old"; done

  echo "state copied to Garage: $root/$stamp.tfstate" >&2
)
