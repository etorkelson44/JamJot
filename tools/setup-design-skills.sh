#!/usr/bin/env bash
# Run from a JamJot Git checkout with: bash tools/setup-design-skills.sh
# Taste selects a visual direction, UI UX Pro Max guides Flutter implementation,
# and Impeccable reviews the result. These are development tools, outside app/.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
if [[ ! -f app/pubspec.yaml ]] || ! grep -Eq '^name: *jamjot *$' app/pubspec.yaml; then
  echo "Run this in the JamJot repository." >&2
  exit 1
fi

scratch=$(mktemp -d "$root/.jamjot-design-setup.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
exclude=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$exclude")"
touch "$exclude"

install_skill() {
  local name=$1 repo=$2 rev=$3 codex=$4 claude=$5
  local checkout="$scratch/$name" provider source path staged pattern
  git init -q "$checkout"
  git -C "$checkout" fetch --quiet --depth=1 "https://github.com/$repo.git" "$rev"
  [[ "$(git -C "$checkout" rev-parse FETCH_HEAD)" == "$rev" ]]
  git -C "$checkout" checkout --quiet --detach FETCH_HEAD
  for provider in .agents .claude; do
    source=$codex
    if [[ $provider == .claude ]]; then source=$claude; fi
    path="$provider/skills/$name"
    mkdir -p "$provider/skills"
    staged=$(mktemp -d "$scratch/stage.XXXXXX")
    cp -R "$checkout/$source/." "$staged/"
    cp "$checkout/LICENSE" "$staged/LICENSE"
    if [[ -f "$checkout/NOTICE.md" ]]; then cp "$checkout/NOTICE.md" "$staged/NOTICE.md"; fi
    if [[ ! -s "$staged/SKILL.md" ]]; then
      rm -rf -- "$staged"
      echo "Missing skill instructions for $name." >&2
      return 1
    fi
    if [[ -e $path || -L $path ]]; then
      if ! diff -qr -x __pycache__ -x .DS_Store "$staged" "$path" >/dev/null; then
        rm -rf -- "$staged"
        echo "Existing $path differs. Review it before replacing it." >&2
        return 1
      fi
      rm -rf -- "$staged"
    else
      # Directory rename publishes a complete skill and refuses a nonempty target.
      python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$staged" "$path"
    fi
    pattern="/$path/"
    if ! grep -Fqx -- "$pattern" "$exclude"; then printf '\n%s\n' "$pattern" >>"$exclude"; fi
    printf 'Ready: %s\n' "$path"
  done
}

install_skill design-taste-frontend Leonxlnx/taste-skill \
  12af471f627f866411b4bd785b19646d3672784c skills/taste-skill skills/taste-skill
install_skill ui-ux-pro-max nextlevelbuilder/ui-ux-pro-max-skill \
  713eef51b04efc98d6fa565323b495f7c9c89fd4 .claude/skills/ui-ux-pro-max .claude/skills/ui-ux-pro-max
install_skill impeccable pbakaus/impeccable \
  9fadc41729c38fd47d7ae622b501558653f9d2e9 .agents/skills/impeccable .claude/skills/impeccable
