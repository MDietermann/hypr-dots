#!/usr/bin/env bash
set -eu
command -v kitten >/dev/null || exit 0
kconf="$HOME/.config/kitty/kitty.conf"
[ -r "$kconf" ] || exit 0
shopt -s nullglob
for s in "${KITTY_SOCK_DIR:-/tmp}"/kitty-*; do
  [ -S "$s" ] || [ -f "$s" ] || continue
  kitten @ --to "unix:$s" set-colors -a -c "$kconf" >/dev/null 2>&1 || true
done
