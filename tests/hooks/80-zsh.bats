#!/usr/bin/env bats
load '../helpers'

setup()    { setup_fake_dotfiles; }
teardown() { teardown_fake_dotfiles; }

@test "80-zsh: writes a marker file with mtime" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/80-zsh.sh" nord
  [ "$status" -eq 0 ]
  [ -f "$HOME/.local/state/theme-switch/zsh-marker" ]
}
