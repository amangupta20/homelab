#!/usr/bin/env bash
# Writes ~/pigsty/pigsty.yml on the node from pigsty.yml.template and OpenBao, and
# applies patch-node.sh, for what Pigsty has no setting for.
# Prints no secret. Needs a token that can read kv/general/pigsty and kv/general/ntfy.
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
remote 'bash -s' <patch-node.sh

# Alertmanager's receiver. Pigsty has no setting for it, only this template.
BAO_NTFY=$(bao kv get -mount=kv -format=json general/ntfy) python3 -c '
import json, os
n = json.loads(os.environ["BAO_NTFY"])["data"]["data"]
print(n["url"].rstrip("/") + "/" + n["topic"] + "?template=alertmanager")
print(n["pigsty_token"])' | remote 'python3 -c "
import os, re, sys
url, token = sys.stdin.read().split()
p = os.path.expanduser(\"~/pigsty/roles/infra/templates/prometheus/alertmanager.yml\")
t = re.sub(r\"    # ntfy begin.*?    # ntfy end\\n\", \"\", open(p).read(), flags=re.S)
block = (\"    # ntfy begin\\n    webhook_configs:\\n      - url: \" + repr(url) + \"\\n        send_resolved: true\\n\"
         \"        http_config:\\n          authorization:\\n            type: Bearer\\n\"
         \"            credentials: \" + repr(token) + \"\\n    # ntfy end\\n\")
k = \"  - name: \" + repr(\"default\") + \"\\n\"
assert t.count(k) == 1
open(p, \"w\").write(t.replace(k, k + block))"'
echo "pigsty.yml written"
