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

@test "--dry-run prints plan, mutates nothing" {
  make_fake_theme default
  make_fake_theme nord
  echo default > "$HOME/.local/state/theme-switch/active"

  run theme-switch --dry-run nord
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow -D theme-default"* ]]
  [[ "$output" == *"stow -R theme-default"* ]]
  [[ "$output" == *"stow --override"* ]]
  [[ "$output" == *"theme-nord"* ]]

  # state/active unchanged
  [ "$(cat "$HOME/.local/state/theme-switch/active")" = "default" ]
}

@test "apply: default→nord moves symlinks into theme-nord" {
  make_fake_theme default
  make_fake_theme nord

  # initial stow so theme-default is the current overlay
  ( cd "$STOW_DIR" && stow -t "$HOME" theme-default )

  # sanity: marker now points into theme-default
  [ "$(readlink -f "$HOME/.config/theme-switch-test/marker")" = \
    "$STOW_DIR/theme-default/.config/theme-switch-test/marker" ]

  echo default > "$HOME/.local/state/theme-switch/active"

  run env THEME_SWITCH_ROOT="$STOW_DIR" \
      THEME_SWITCH_STATE="$HOME/.local/state/theme-switch" \
      theme-switch nord
  [ "$status" -eq 0 ]
  [ "$(readlink -f "$HOME/.config/theme-switch-test/marker")" = \
    "$STOW_DIR/theme-nord/.config/theme-switch-test/marker" ]
  [ "$(cat "$HOME/.local/state/theme-switch/active")" = "nord" ]
}

@test "flock: second concurrent run fails fast" {
  make_fake_theme default
  make_fake_theme nord
  ( cd "$STOW_DIR" && stow -t "$HOME" theme-default )
  echo default > "$HOME/.local/state/theme-switch/active"

  # hold the lock in background
  ( exec 200>"$HOME/.local/state/theme-switch/lock"; flock -x 200; sleep 0.5 ) &
  bg_pid=$!
  sleep 0.1

  run theme-switch nord
  kill $bg_pid 2>/dev/null || true
  wait 2>/dev/null || true

  [ "$status" -eq 1 ]
  [[ "$output" == *"already running"* ]]
}
