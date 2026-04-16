#!/usr/bin/env bats
load 'helpers'

setup()    { setup_fake_dotfiles; }
teardown() { teardown_fake_dotfiles; }

@test "--list returns theme names, excluding template" {
  make_fake_theme default
  make_fake_theme nord
  make_fake_theme dracula
  mkdir -p "$STOW_DIR/theme-template"

  run theme-switch --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"default"* ]]
  [[ "$output" == *"nord"* ]]
  [[ "$output" == *"dracula"* ]]
  [[ "$output" != *"template"* ]]
}

@test "--current returns 'default' when no state" {
  make_fake_theme default
  run theme-switch --current
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

@test "--current returns written state" {
  make_fake_theme nord
  echo nord > "$HOME/.local/state/theme-switch/active"
  export THEME_SWITCH_STATE="$HOME/.local/state/theme-switch"
  run theme-switch --current
  [ "$status" -eq 0 ]
  [ "$output" = "nord" ]
}

@test "apply: unknown theme exits 1 with helpful message" {
  make_fake_theme default
  run theme-switch foo
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"not found"* || "$output" == *"not found"* ]]
}
