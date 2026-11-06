#!/usr/bin/env bash
# Writes ~/pigsty/pigsty.yml on the node from pigsty.yml.template and OpenBao, and
# turns off Grafana's anonymous access, which Pigsty hard-codes in a template.
# Prints no secret. Needs a token that can read kv/general/pigsty.
#
#   ./render.sh --check   compare with what is on the node; changes nothing
#   ./render.sh           write it. Applying it is a separate Pigsty playbook run.
set -euo pipefail
cd "$(dirname "$0")"
node=ubuntu@pigsty-1
key=~/.ssh/pigsty
remote() { ssh -i "$key" -o BatchMode=yes "$node" "$@"; }

rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT
chmod 600 "$rendered"

TS_IP=$(remote tailscale ip -4) \
BAO_JSON=$(bao kv get -mount=kv -format=json general/pigsty) \
python3 - "$rendered" <<'PY'
import json, os, re, sys
secrets = json.loads(os.environ["BAO_JSON"])["data"]["data"]
values = {k.upper(): str(v) for k, v in secrets.items()}
values["TAILSCALE_IP"] = os.environ["TS_IP"]
values["B2_ENDPOINT_HOST"] = secrets["endpoint_url"].removeprefix("https://")
text = open("pigsty.yml.template").read()
missing = sorted(set(re.findall(r"__([A-Z0-9_]+)__", text)) - set(values))
if missing:
    sys.exit(f"not in kv/general/pigsty: {missing}")
text = text[text.index("all:\n"):]  # the header comment stays in the repo
text = re.sub(r"__([A-Z0-9_]+)__", lambda m: values[m.group(1)], text)
open(sys.argv[1], "w").write(text)
PY

if [[ "${1:-}" == "--check" ]]; then
  ours=$(sha256sum <"$rendered" | cut -d' ' -f1)
  theirs=$(remote 'sha256sum < ~/pigsty/pigsty.yml' | cut -d' ' -f1)
  [[ "$ours" == "$theirs" ]] && echo "pigsty.yml matches" || { echo "pigsty.yml differs"; exit 1; }
  exit 0
fi

remote 'umask 077; cat > ~/pigsty/pigsty.yml' <"$rendered"
remote "sed -i '/^\[auth.anonymous\]/,/^\[/ s/^enabled = true/enabled = false/' ~/pigsty/roles/infra/templates/grafana/grafana.ini.j2"
echo "pigsty.yml written"
