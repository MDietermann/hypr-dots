#!/usr/bin/env bash
set -eu
command -v waybar >/dev/null || exit 0
pkill -SIGUSR2 waybar || nohup waybar >/dev/null 2>&1 &
