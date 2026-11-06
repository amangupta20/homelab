#!/usr/bin/env bash
# Runs on pigsty-1 (render.sh sends it). Changes Pigsty's own files where it has no setting:
# - Grafana's anonymous access, hard-coded on in a template.
# - Apt lists, which Pigsty writes without signature checks. This pins each publisher's key and
#   has the templates use it. The local repo keeps no signature: it has none, and holds only
#   packages downloaded through the checked sources.
set -euo pipefail
sudo install -d -m 755 /etc/apt/keyrings
add_key() { # name, full fingerprint, source file or URL
  if [[ -f "/etc/apt/keyrings/$1.asc" ]] && gpg --show-keys --with-colons "/etc/apt/keyrings/$1.asc" | grep -q "^fpr:.*:$2:"; then echo "key present: $1"; return; fi
  tmp=$(mktemp); case "$3" in http*) curl -fsSL --max-time 20 "$3" >"$tmp";; *) cp "$3" "$tmp";; esac
  fp=$(gpg --show-keys --with-colons "$tmp" | awk -F: '/^fpr/{print $10; exit}')
  [[ "$fp" == "$2" ]] || { echo "wrong key for $1: $fp"; rm -f "$tmp"; exit 1; }
  sudo install -m 644 "$tmp" "/etc/apt/keyrings/$1.asc"; rm -f "$tmp"; echo "key ok: $1"
}
add_key pigsty 9592A7BC7A682E7333376E09E7935D8DB9BD8B20 "$HOME/pigsty/KEYS"
add_key pgdg B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 https://www.postgresql.org/media/keys/ACCC4CF8.asc
add_key docker 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 https://download.docker.com/linux/ubuntu/gpg

cd "$HOME/pigsty"
sed -i '/^\[auth.anonymous\]/,/^\[/ s/^enabled = true/enabled = false/' roles/infra/templates/grafana/grafana.ini.j2
python3 - <<'PY'
opt = ("{{ {'pigsty-pgsql':'pigsty','pigsty-infra':'pigsty','pgdg':'pgdg','docker-ce':'docker'}.get(repo.name) "
       "| ternary('signed-by=/etc/apt/keyrings/' ~ {'pigsty-pgsql':'pigsty','pigsty-infra':'pigsty','pgdg':'pgdg',"
       "'docker-ce':'docker'}.get(repo.name) ~ '.asc', 'trusted=yes') }}")
for p in ("roles/repo/tasks/build.yml", "roles/node/tasks/pkg.yml"):
    t = open(p).read()
    open(p, "w").write(t.replace("deb [trusted=yes] {{ repo.baseurl", "deb [" + opt + "] {{ repo.baseurl"))
PY
# The lists already on the node
sudo sed -i -E '
  s#deb \[trusted=yes\] (https://repo.pigsty.io)#deb [signed-by=/etc/apt/keyrings/pigsty.asc] \1#
  s#deb \[trusted=yes\] (http://apt.postgresql.org)#deb [signed-by=/etc/apt/keyrings/pgdg.asc] \1#
  s#deb \[trusted=yes\] (https://download.docker.com)#deb [signed-by=/etc/apt/keyrings/docker.asc] \1#
' /etc/apt/sources.list.d/infra.list /etc/apt/sources.list.d/pgsql.list
echo patched

# Pigsty's rules have no alert for failed WAL archiving, which would fill the disk. A file in its
# rules folder survives an infra rerun, which copies the whole folder.
rule=$(cat <<'YAML'
---
groups:
  - name: pg-archive
    rules:
      - alert: PostgresArchiveFailing
        expr: increase(pg_archiver_failed_count[10m]) > 0
        for: 5m
        labels: { level: 1, severity: WARN, category: pgsql }
        annotations:
          summary: "WAL archiving is failing on {{ $labels.ins }}"
          description: "pg_archiver_failed_count rose by {{ $value }} in 10 minutes. Backups have stopped, and pg_wal will grow until the disk fills."
YAML
)
printf '%s\n' "$rule" > files/victoria/rules/pg-archive.yml
printf '%s\n' "$rule" | sudo tee /infra/rules/pg-archive.yml >/dev/null
sudo chown victoria /infra/rules/pg-archive.yml 2>/dev/null || true
sudo systemctl kill -s HUP vmalert 2>/dev/null || sudo systemctl restart vmalert
