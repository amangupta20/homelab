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
# A failed copy warns and returns 0: the change it follows has already happened,
# so failing the command would only hide that. `./run.sh backup` retries it, with
# STATE_COPY_STRICT=1 so that a failure there exits 1.

STATE_COPY_KEEP=14

# state_copy <key of the state object in B2, e.g. oci/terraform.tfstate>
state_copy() (
  set -eu
  key=$1
  root=${key%%/*}
  stamp=$(date -u +%Y%m%dT%H%M%SZ)

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

  if ! rclone copyto --contimeout 10s --timeout 60s --retries 1 --low-level-retries 2 -q "$src" "$dst"; then
    echo "WARNING: state copy to Garage failed for $key; retry with ./run.sh backup" >&2
    return "${STATE_COPY_STRICT:-0}"
  fi

  # rclone compares only sizes here (B2 keeps SHA-1, Garage MD5), so compare
  # the bytes themselves. State files are small.
  a=$(rclone cat "$src" | sha256sum | cut -d' ' -f1)
  b=$(rclone cat "$dst" | sha256sum | cut -d' ' -f1)
  if [ "$a" != "$b" ]; then
    echo "WARNING: Garage copy $stamp of $key does not match B2; retry with ./run.sh backup" >&2
    return "${STATE_COPY_STRICT:-0}"
  fi

  rclone lsf --files-only "$dir" | sort | head -n "-$STATE_COPY_KEEP" |
    while read -r old; do rclone deletefile -q "$dir/$old"; done

  echo "state copied to Garage: $root/$stamp.tfstate" >&2
)

# state_changes <tofu subcommand>: true when the command can change state.
state_changes() {
  case "${1:-}" in
    apply | destroy | import | state | taint | untaint) return 0 ;;
    *) return 1 ;;
  esac
}
