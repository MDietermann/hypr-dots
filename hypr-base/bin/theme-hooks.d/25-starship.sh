#!/usr/bin/env bash
# Sync starship palette with the active theme-switch theme.
set -eu

theme="${1:-default}"
config="$HOME/.config/starship.toml"

[ -f "$config" ] || { echo "25-starship: $config missing, skipping" >&2; exit 0; }

case "$theme" in
  dracula)  palette="dracula" ;;
  nord)     palette="nord" ;;
  default|tokyonight) palette="tokyonight" ;;
  *)
    echo "25-starship: no palette mapping for '$theme', leaving config untouched" >&2
    exit 0
    ;;
esac

tmp=$(mktemp "${config}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

sed -E "s|^palette = \".*\"|palette = \"${palette}\"|" "$config" > "$tmp"

if ! grep -q "^palette = \"${palette}\"" "$tmp"; then
  echo "25-starship: could not rewrite palette line in $config" >&2
  exit 1
fi

mv "$tmp" "$config"
trap - EXIT
echo "25-starship: palette → ${palette}"
