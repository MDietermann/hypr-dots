#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  mkdir -p "$HOME/.config/kitty"
  touch "$HOME/.config/kitty/kitty.conf"
  export KITTY_SOCK_DIR="$TMP_ROOT/kitty-socks"
  mkdir -p "$KITTY_SOCK_DIR"
}
teardown() { teardown_fake_dotfiles; }

@test "20-kitty: no sockets → exits 0, no calls" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  [ "$status" -eq 0 ]
  [ ! -s "$THEME_SWITCH_TEST_LOG" ]
}

@test "20-kitty: sockets present → kitten called once per socket" {
  touch "$KITTY_SOCK_DIR/kitty-11111" "$KITTY_SOCK_DIR/kitty-22222"
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  [ "$status" -eq 0 ]
  [ "$(grep -c '^kitten' "$THEME_SWITCH_TEST_LOG")" -eq 2 ]
}
