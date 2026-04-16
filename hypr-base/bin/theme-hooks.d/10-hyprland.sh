#!/usr/bin/env bash
set -eu
command -v hyprctl >/dev/null || exit 0
hyprctl reload >/dev/null
