#!/usr/bin/env bash
set -eu
theme="$1"
command -v nvim >/dev/null || exit 0

# Find the colorscheme from theme's meta.toml
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
cs="$theme"
if [ -r "$meta" ]; then
  cs=$(awk -F'=' '/^[[:space:]]*colorscheme[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta") || cs="$theme"
fi

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
shopt -s nullglob
for sock in "$runtime"/nvim-*; do
  nvim --server "$sock" --remote-send ":colorscheme $cs<CR>" >/dev/null 2>&1 || true
done
