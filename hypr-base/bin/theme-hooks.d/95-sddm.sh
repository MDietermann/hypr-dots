#!/usr/bin/env bash
set -eu
theme="$1"
helper="${TS_SDDM_HELPER:-/usr/local/bin/theme-apply-sddm}"
if command -v pkexec >/dev/null && [ -x "$helper" ]; then
  pkexec "$helper" "$theme" || {
    command -v notify-send >/dev/null && notify-send -u critical "theme-switch" "SDDM update failed" || true
  }
else
  command -v notify-send >/dev/null && notify-send "theme-switch" "SDDM helper missing; run install/install.sh" || true
fi
exit 0
