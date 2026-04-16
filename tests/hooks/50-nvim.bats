#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  mkdir -p "$TMP_ROOT/bin"
  cat > "$TMP_ROOT/bin/nvim" <<'SEOF'
#!/usr/bin/env bash
echo "nvim $*" >> "$THEME_SWITCH_TEST_LOG"
exit 0
SEOF
  chmod +x "$TMP_ROOT/bin/nvim"
  export PATH="$TMP_ROOT/bin:$PATH"
  export XDG_RUNTIME_DIR="$TMP_ROOT/run"
  mkdir -p "$XDG_RUNTIME_DIR"
  make_fake_theme nord
}
teardown() { teardown_fake_dotfiles; }

@test "50-nvim: no sockets → no calls" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/50-nvim.sh" nord
  [ "$status" -eq 0 ]
  ! grep -q '^nvim' "$THEME_SWITCH_TEST_LOG"
}

@test "50-nvim: sends :colorscheme to each nvim socket" {
  : > "$XDG_RUNTIME_DIR/nvim-1234"
  : > "$XDG_RUNTIME_DIR/nvim-5678"
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/50-nvim.sh" nord
  [ "$status" -eq 0 ]
  [ "$(grep -c '^nvim' "$THEME_SWITCH_TEST_LOG")" -eq 2 ]
  grep -q 'colorscheme nord' "$THEME_SWITCH_TEST_LOG"
}
