#!/usr/bin/env sh
# Links every skill in agents/skills/ into the harnesses listed in agents/harnesses.txt
# (the ones that only read a folder in your home directory). Safe to re-run:
# existing links are kept, broken links into this repo (a removed or moved
# skill) are cleaned up,
# and anything that is not this repo's link is left alone and reported.
#
# Exit status 1 means something needs your attention: a name clash, or (for
# "adopt" harnesses) a skill an agent wrote outside the repo.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
skills="$root/agents/skills"
attention=0

while read -r name dir mode; do
  case "$name" in '' | '#'*) continue ;; esac
  case "$dir" in "~/"*) dir="$HOME/${dir#"~/"}" ;; esac

  # The harness's own home (e.g. ~/.hermes) must exist: no home, not installed.
  if [ ! -d "$(dirname "$dir")" ]; then
    echo "$name: not installed here ($(dirname "$dir") missing), skipped"
    continue
  fi
  mkdir -p "$dir"

  # Broken links into this repo first: a skill that was removed, or a link
  # left from before skills moved from skills/ to agents/skills/.
  for dest in "$dir"/*; do
    [ -L "$dest" ] || continue
    case "$(readlink "$dest")" in
      "$root"/*)
        if [ ! -e "$dest" ]; then
          rm "$dest"
          echo "$name: removed $(basename "$dest") (its target in this repo is gone)"
        fi
        ;;
    esac
  done

  for src in "$skills"/*/; do
    src=${src%/}
    [ -f "$src/SKILL.md" ] || continue
    skill=$(basename "$src")
    dest="$dir/$skill"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      continue
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "$name: $dest already exists and is not this repo's link, left alone"
      attention=1
    else
      ln -s "$src" "$dest"
      echo "$name: linked $skill"
    fi
  done

  if [ "${mode:-}" = adopt ]; then
    for dest in "$dir"/*; do
      [ -L "$dest" ] && continue
      if [ -f "$dest/SKILL.md" ]; then
        echo "$name: $(basename "$dest") was written outside the repo; move it to agents/skills/ and propose it (agents/skills/write-a-skill/)"
        attention=1
      fi
    done
  fi
done <"$root/agents/harnesses.txt"

exit "$attention"
