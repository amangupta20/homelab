#!/bin/sh
# Import a Debian 13 cloud image into Xen Orchestra as a VM template.
#
# Usage: ./debian-13.sh <build>     e.g. ./debian-13.sh 20261111-2659
# Builds are the folders under https://cloud.debian.org/images/cloud/trixie/.
#
# What it does, in order (each step ran by hand on 2026-11-16 for build
# 20261111-2659; this script strings them together and is UNTESTED as a whole):
#   1. checks the raw image's SHA-512 against Debian's SHA512SUMS, streaming it
#      through sha512sum on this machine (about 3.2 GB of download, nothing saved);
#   2. has Xen Orchestra download the same file itself and import it into
#      "Local storage", so the image never crosses the tailnet. Xen Orchestra
#      only imports VHD or raw from a URL; qcow2 is refused;
#   3. creates a halted VM from Xen Orchestra's built-in "Other install media"
#      template, set to UEFI, with no network card, attaches the image as its
#      boot disk, and converts it to a template. "Other install media" is the
#      only built-in template whose static memory minimum is 128 MiB; the
#      "Debian Trixie 13" one fixes it at 1 GiB, which Xen Orchestra cannot
#      lower, and that would forbid a dynamic minimum below 1 GiB.
# The VM is never booted before it becomes a template: a first boot runs
# cloud-init and would bake a machine ID and SSH host keys into every clone.
#
# Needs: bao (logged in), curl, jq, node 22+.
set -eu
cd "$(dirname "$0")"

build=${1:?usage: $0 <build, e.g. 20261111-2659>}
base=https://cloud.debian.org/images/cloud/trixie/$build
file=debian-13-generic-amd64-$build.raw
name=debian-13-cloud-$build
storage="Local storage"
base_template="Other install media"

XO_URL=$(bao kv get -mount=kv -field=url homelab/xo)
XO_TOKEN=$(bao kv get -mount=kv -field=token homelab/xo)
export XO_URL XO_TOKEN

# GET or POST against Xen Orchestra's REST API. Its certificate is self-signed.
rest() {
  path=$1
  shift
  curl -skf -b "authenticationToken=$XO_TOKEN" "$@" "$XO_URL/rest/v0/$path"
}
rpc() { node --no-warnings xo-rpc.mjs "$@"; }

if rest "vm-templates?fields=name_label" | jq -e --arg n "$name" 'any(.[]; .name_label == $n)' >/dev/null; then
  echo "template $name already exists; nothing to do" >&2
  exit 0
fi

echo "1/4 checking $file against SHA512SUMS (downloads it once)" >&2
want=$(curl -sf "$base/SHA512SUMS" | awk -v f="$file" '$2 == f { print $1 }')
[ -n "$want" ] || { echo "$file is not in $base/SHA512SUMS" >&2; exit 1; }
got=$(curl -sfL "$base/$file" | sha512sum | cut -d' ' -f1)
[ "$want" = "$got" ] || { echo "SHA-512 mismatch for $file" >&2; exit 1; }

sr=$(rest "srs?fields=name_label,uuid" | jq -r --arg n "$storage" '.[] | select(.name_label == $n) | .uuid')
pool=$(rest "pools?fields=uuid" | jq -r '.[0].uuid')
tmpl=$(rest "vm-templates?fields=name_label,uuid" |
  jq -r --arg n "$base_template" '.[] | select(.name_label == $n) | .uuid')
[ -n "$sr" ] && [ -n "$pool" ] && [ -n "$tmpl" ] || { echo "storage, pool or base template not found" >&2; exit 1; }

echo "2/4 Xen Orchestra imports the image from Debian (took 11 min on 2026-11-16)" >&2
vdi=$(rpc disk.import "$(jq -nc --arg sr "$sr" --arg name "$file" --arg url "$base/$file" \
  --arg d "Debian 13 generic cloud image, build $build, SHA-512 checked" \
  '{sr: $sr, type: "raw", name: $name, description: $d, url: $url}')" | jq -r .)

echo "3/4 creating $name and attaching the disk" >&2
vm=$(rest "pools/$pool/actions/create_vm?sync=true" -X POST -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg n "$name" --arg t "$tmpl" --arg b "$build" '{
    name_label: $n, template: $t, cpus: 1, memory: 268435456, boot: false, vifs: [],
    hvmBootFirmware: "uefi",
    name_description: ("Template: Debian 13 generic cloud image " + $b + " (cloud-init), UEFI, static memory minimum 128 MiB. Base: Other install media. See iac/README.md.")
  }')" | jq -r .id)
rest vbds -X POST -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg vm "$vm" --arg vdi "$vdi" \
    '{VM: $vm, VDI: $vdi, type: "Disk", mode: "RW", bootable: true, userdevice: "0"}')" >/dev/null

echo "4/4 converting it to a template" >&2
rpc vm.convertToTemplate "$(jq -nc --arg id "$vm" '{id: $id}')" >/dev/null

echo "template $name ($vm) is ready; boot-test a clone before using it (iac/README.md)" >&2
