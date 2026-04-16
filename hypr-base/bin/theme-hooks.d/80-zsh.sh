#!/usr/bin/env bash
set -eu
state="${THEME_SWITCH_STATE:-$HOME/.local/state/theme-switch}"
mkdir -p "$state"
: > "$state/zsh-marker"
