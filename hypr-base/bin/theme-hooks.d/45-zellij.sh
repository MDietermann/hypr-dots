#!/usr/bin/env bash
set -eu
command -v zellij >/dev/null || exit 0
# List active (non-EXITED) sessions and tell each to re-read the 'current' theme.
# zellij 0.40+ has `action switch-theme`; older versions will just skip.
zellij list-sessions -n 2>/dev/null | awk '!/EXITED/ {print $1}' | while read -r s; do
  [ -z "$s" ] && continue
  zellij --session "$s" action switch-theme current >/dev/null 2>&1 || true
done
