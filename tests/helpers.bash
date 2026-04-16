# tests/helpers.bash — sourced by every .bats file

setup_fake_dotfiles() {
  TMP_ROOT=$(mktemp -d)
  _ORIG_PATH="$PATH"
  export HOME="$TMP_ROOT/home"
  export STOW_DIR="$HOME/hypr-dots"
  mkdir -p "$HOME"
  mkdir -p "$STOW_DIR" "$HOME/.config" "$HOME/.local/state/theme-switch"
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_ROOT="$STOW_DIR"
}

teardown_fake_dotfiles() {
  [ -n "${TMP_ROOT:-}" ] && rm -rf "$TMP_ROOT"
  [ -n "${_ORIG_PATH:-}" ] && export PATH="$_ORIG_PATH"
}

make_fake_theme() {
  local name="$1"
  local pkg="$STOW_DIR/theme-$name"
  mkdir -p "$pkg/.config/theme-switch-test"
  echo "$name" > "$pkg/.config/theme-switch-test/marker"
  cat > "$pkg/meta.toml" <<EOF
name = "$name"
description = "fake theme for tests"
accent = "#abcdef"
colorscheme = "$name"
gtk_theme = "Adw"
icon_theme = "Adw"
cursor_theme = "Adw"
cursor_size = 24
EOF
}
