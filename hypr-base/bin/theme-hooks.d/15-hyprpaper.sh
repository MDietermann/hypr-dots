#!/usr/bin/env bash
set -eu
command -v hyprctl >/dev/null || exit 0
conf="$HOME/.config/hypr/hyprpaper.conf"
[ -r "$conf" ] || exit 0
wall=$(awk -F'=' '/^[[:space:]]*preload[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$conf")
[ -n "$wall" ] || exit 0
# expand ~
wall="${wall/#\~/$HOME}"
hyprctl hyprpaper unload all >/dev/null || true
hyprctl hyprpaper preload "$wall" >/dev/null || true
if command -v jq >/dev/null; then
  mons=$(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' || true)
else
  # Match only top-level "name": "<value>" (4-space indent) to avoid nested workspace fields
  mons=$(hyprctl -j monitors 2>/dev/null | awk -F'"' '/^    "name":/ {print $4}' || true)
fi
if [ -z "$mons" ]; then
  hyprctl hyprpaper wallpaper ",$wall" >/dev/null || true
else
  for m in $mons; do
    hyprctl hyprpaper wallpaper "$m,$wall" >/dev/null || true
  done
fi
