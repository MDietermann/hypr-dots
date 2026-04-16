#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
REPO=$(readlink -f "$HERE/../..")

docker build -t theme-switch-it -f "$HERE/Dockerfile" "$HERE"

docker run --rm -v "$REPO:/home/marvin/hypr-dots:ro" theme-switch-it bash -euc '
  cp -a /home/marvin/hypr-dots /home/marvin/work
  cd /home/marvin/work
  mkdir -p /home/marvin/.local/state/theme-switch
  cd /home/marvin
  stow -d /home/marvin/work hypr-base theme-default
  PATH=/home/marvin/bin:/usr/bin theme-switch nord
  PATH=/home/marvin/bin:/usr/bin theme-switch dracula
  test "$(cat /home/marvin/.local/state/theme-switch/active)" = dracula
  PATH=/home/marvin/bin:/usr/bin theme-switch --rollback
  test "$(cat /home/marvin/.local/state/theme-switch/active)" = nord
  echo "integration: OK"
'
