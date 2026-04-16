#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
}
teardown() { teardown_fake_dotfiles; }

@test "60-gtk: sets gtk-theme, icon-theme, cursor-theme from meta.toml" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/60-gtk.sh" nord
  [ "$status" -eq 0 ]
  grep -q 'gsettings set .*gtk-theme' "$THEME_SWITCH_TEST_LOG"
  grep -q 'gsettings set .*icon-theme' "$THEME_SWITCH_TEST_LOG"
  grep -q 'gsettings set .*cursor-theme' "$THEME_SWITCH_TEST_LOG"
}
