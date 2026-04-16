#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
}
teardown() { teardown_fake_dotfiles; }

@test "70-cursor: calls hyprctl setcursor with meta values" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/70-cursor.sh" nord
  [ "$status" -eq 0 ]
  grep -qE 'hyprctl setcursor Adw 24' "$THEME_SWITCH_TEST_LOG"
}
