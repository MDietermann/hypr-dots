#!/usr/bin/env bash
set -eu
theme="$1"
command -v hyprctl >/dev/null || exit 0
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
[ -r "$meta" ] || exit 0
read_meta() { awk -F'=' -v k="$1" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta"; }
cursor=$(read_meta cursor_theme); size=$(read_meta cursor_size)
if [ -n "$cursor" ] && [ -n "$size" ]; then
  hyprctl setcursor "$cursor" "$size" >/dev/null || true
fi
