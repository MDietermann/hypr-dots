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
