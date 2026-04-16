#!/usr/bin/env bash
set -eu
theme="$1"
command -v gsettings >/dev/null || exit 0
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
[ -r "$meta" ] || exit 0

read_meta() {
  awk -F'=' -v k="$1" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta"
}
gtk=$(read_meta gtk_theme)
icons=$(read_meta icon_theme)
cursor=$(read_meta cursor_theme)

[ -n "$gtk" ]    && gsettings set org.gnome.desktop.interface gtk-theme    "$gtk"    || true
[ -n "$icons" ]  && gsettings set org.gnome.desktop.interface icon-theme   "$icons"  || true
[ -n "$cursor" ] && gsettings set org.gnome.desktop.interface cursor-theme "$cursor" || true
