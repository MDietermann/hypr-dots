#!/usr/bin/env bats
load '../helpers'

setup()    { setup_fake_dotfiles; export REPO_ROOT="$BATS_TEST_DIRNAME/../.."; export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"; export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"; }
teardown() { teardown_fake_dotfiles; }

@test "10-hyprland: calls 'hyprctl reload'" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/10-hyprland.sh" nord
  [ "$status" -eq 0 ]
  grep -qE '^hyprctl reload$' "$THEME_SWITCH_TEST_LOG"
}

@test "10-hyprland: exits 0 when hyprctl absent" {
  PATH=/usr/bin:/bin run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/10-hyprland.sh" nord
  [ "$status" -eq 0 ]
}
