#!/bin/sh
# Run tofu in this directory with credentials from OpenBao. Nothing is written
# to disk or to the shell's environment. Usage: ./run.sh init | plan | apply | ...
# After a command that can change state, the encrypted state is copied to Garage
# (lib/state-copy.sh); `./run.sh backup` makes that copy on its own.
# Needs: bao, tofu, rclone, BAO_ADDR set, and `bao login` done once on this machine.
set -eu
cd "$(dirname "$0")"
. ./lib/state-copy.sh
STATE_KEY=xcp-ng/terraform.tfstate

if [ "${1:-}" = "backup" ]; then
  STATE_COPY_STRICT=1 state_copy "$STATE_KEY"
  exit
fi

b2() { bao kv get -mount=kv -field="$1" general/tofub2; }

AWS_ACCESS_KEY_ID=$(b2 keyID)
AWS_SECRET_ACCESS_KEY=$(b2 applicationKey)
TF_VAR_state_passphrase=$(bao kv get -mount=kv -field=passphrase general/tofu-state)
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY TF_VAR_state_passphrase

if [ "${1:-}" = "init" ]; then
  shift
  exec tofu init -backend-config="bucket=$(b2 bucket_name)" "$@"
fi

# The provider wants a websocket URL; OpenBao stores the web address.
XOA_URL=$(bao kv get -mount=kv -field=url homelab/xo | sed 's|^https://|wss://|; s|^http://|ws://|')
XOA_TOKEN=$(bao kv get -mount=kv -field=token homelab/xo)
XOA_INSECURE=true
export XOA_URL XOA_TOKEN XOA_INSECURE

rc=0
tofu "$@" || rc=$?
if state_changes "${1:-}"; then state_copy "$STATE_KEY"; fi
exit "$rc"
