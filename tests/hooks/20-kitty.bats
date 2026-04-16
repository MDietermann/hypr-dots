#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  mkdir -p "$HOME/.config/kitty"
  touch "$HOME/.config/kitty/kitty.conf"
}
teardown() { teardown_fake_dotfiles; }

@test "20-kitty: no sockets → exits 0, no calls" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  [ "$status" -eq 0 ]
  [ ! -s "$THEME_SWITCH_TEST_LOG" ]
}

@test "20-kitty: sockets present → kitten called once per socket" {
  mkdir -p /tmp/theme-switch-test-sockets
  export KITTY_SOCK_DIR=/tmp/theme-switch-test-sockets
  touch /tmp/kitty-11111 /tmp/kitty-22222
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  rm -f /tmp/kitty-11111 /tmp/kitty-22222
  [ "$status" -eq 0 ]
  [ "$(grep -c '^kitten' "$THEME_SWITCH_TEST_LOG")" -eq 2 ]
}
