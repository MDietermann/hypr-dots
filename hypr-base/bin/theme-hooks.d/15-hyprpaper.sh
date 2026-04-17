#!/usr/bin/env bash
set -eu
command -v hyprctl >/dev/null || exit 0
conf="$HOME/.config/hypr/hyprpaper.conf"
[ -r "$conf" ] || exit 0
wall=$(awk '
  /^[[:space:]]*wallpaper[[:space:]]*\{/ { inblock=1; next }
  inblock && /^[[:space:]]*\}/          { inblock=0; next }
  inblock && /^[[:space:]]*path[[:space:]]*=/ {
    sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]+$/, "");
    print; exit
  }
' "$conf")
[ -n "$wall" ] || exit 0
wall="${wall/#\~/$HOME}"
if command -v jq >/dev/null; then
  mons=$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' || true)
else
  mons=$(hyprctl -j monitors 2>/dev/null | awk -F'"' '/^    "name":/ {print $4}' || true)
fi
if [ -z "$mons" ]; then
  hyprctl hyprpaper wallpaper ",$wall" >/dev/null || true
else
  for m in $mons; do
    hyprctl hyprpaper wallpaper "$m,$wall" >/dev/null || true
  done
fi
