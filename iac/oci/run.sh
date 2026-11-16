#!/bin/sh
# Run tofu in this directory with credentials from OpenBao. Nothing is written
# to disk or to the shell's environment. Usage: ./run.sh init | plan | apply | ...
# After every command, the encrypted state is synced to Garage if it changed
# (../lib/state-copy.sh); `./run.sh backup` runs that sync on its own.
# Needs: bao, tofu, rclone, BAO_ADDR set, and `bao login` done once on this machine.
set -eu
cd "$(dirname "$0")"
. ../lib/state-copy.sh
STATE_KEY=oci/terraform.tfstate

if [ "${1:-}" = "backup" ]; then
  state_sync "$STATE_KEY"
  exit
fi

oci() { bao kv get -mount=kv -field="$1" general/oci; }
b2() { bao kv get -mount=kv -field="$1" general/tofub2; }

AWS_ACCESS_KEY_ID=$(b2 keyID)
AWS_SECRET_ACCESS_KEY=$(b2 applicationKey)
TF_VAR_state_passphrase=$(bao kv get -mount=kv -field=passphrase general/tofu-state)
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY TF_VAR_state_passphrase

# init only touches the state bucket, so it works before the Oracle secrets exist.
if [ "${1:-}" = "init" ]; then
  shift
  exec tofu init -backend-config="bucket=$(b2 bucket_name)" "$@"
fi

TF_VAR_tenancy_ocid=$(oci tenancy_ocid)
TF_VAR_user_ocid=$(oci user_ocid)
TF_VAR_fingerprint=$(oci fingerprint)
TF_VAR_private_key=$(oci private_key)
TF_VAR_region=$(oci region)
TF_VAR_compartment_ocid=$(oci compartment_ocid)
TF_VAR_ssh_public_key=$(oci ssh_public_key)
TF_VAR_tailscale_auth_key=$(bao kv get -mount=kv -field=auth_key general/tailscale-oci)
export TF_VAR_tenancy_ocid TF_VAR_user_ocid TF_VAR_fingerprint TF_VAR_private_key \
  TF_VAR_region TF_VAR_compartment_ocid TF_VAR_ssh_public_key TF_VAR_tailscale_auth_key

rc=0
tofu "$@" || rc=$?
# Garage is only the second copy: its result never changes the exit code.
state_sync "$STATE_KEY" || true
exit "$rc"
