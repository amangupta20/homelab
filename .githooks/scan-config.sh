# Sourced by the hooks and `mise run scan`; not a hook itself.
#
# build_scan_config <file> writes the gitleaks config every scan uses into
# <file>, a throwaway path:
#
# - gitleaks exempts the exact path it is handed as -c from being scanned, so
#   passing secret-scan.toml directly would make the rules file the one file no
#   scan can see. A copy makes it an ordinary target. (The file is also not
#   named .gitleaks.toml: the built-in default config excludes every path
#   matching gitleaks\.toml.)
# - secret-scan.local.toml, if present, is appended. It holds patterns that
#   would leak by being committed (your real domains), so it is git-ignored
#   and exists only on machines you set it up on.
build_scan_config() {
  cp secret-scan.toml "$1"
  if [ -f secret-scan.local.toml ]; then
    printf '\n' >>"$1"
    cat secret-scan.local.toml >>"$1"
  else
    echo "note: no secret-scan.local.toml here, so your own domains are not checked." >&2
    echo "      See repo/secret-scanning.md (Private rules)." >&2
  fi
}
