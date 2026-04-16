#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
  mkdir -p "$STOW_DIR/theme-nord/.config/hypr"
  mkdir -p "$STOW_DIR/theme-nord/.local/share/wallpapers"
  : > "$STOW_DIR/theme-nord/.local/share/wallpapers/nord.png"
  mkdir -p "$HOME/.local/share/wallpapers"
  ln -sf "$STOW_DIR/theme-nord/.local/share/wallpapers/nord.png" \
         "$HOME/.local/share/wallpapers/nord.png"
  cat > "$STOW_DIR/theme-nord/.config/hypr/hyprpaper.conf" <<EOFF
preload = ~/.local/share/wallpapers/nord.png
wallpaper = , ~/.local/share/wallpapers/nord.png
EOFF
  mkdir -p "$HOME/.config/hypr"
  ln -sf "$STOW_DIR/theme-nord/.config/hypr/hyprpaper.conf" \
         "$HOME/.config/hypr/hyprpaper.conf"
}
teardown() { teardown_fake_dotfiles; }

@test "15-hyprpaper: preloads and sets wallpaper" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/15-hyprpaper.sh" nord
  [ "$status" -eq 0 ]
  grep -q 'hyprctl hyprpaper unload all' "$THEME_SWITCH_TEST_LOG"
  grep -q 'hyprctl hyprpaper preload' "$THEME_SWITCH_TEST_LOG"
  grep -q 'hyprctl hyprpaper wallpaper' "$THEME_SWITCH_TEST_LOG"
}
