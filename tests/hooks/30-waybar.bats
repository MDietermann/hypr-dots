#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  mkdir -p "$TMP_ROOT/bin"
  cat > "$TMP_ROOT/bin/pkill" <<'SEOF'
#!/usr/bin/env bash
echo "pkill $*" >> "$THEME_SWITCH_TEST_LOG"
exit 0
SEOF
  chmod +x "$TMP_ROOT/bin/pkill"
  cat > "$TMP_ROOT/bin/waybar" <<'SEOF'
#!/usr/bin/env bash
echo "waybar $*" >> "$THEME_SWITCH_TEST_LOG"
exit 0
SEOF
  chmod +x "$TMP_ROOT/bin/waybar"
  export PATH="$TMP_ROOT/bin:$PATH"
}
teardown() { teardown_fake_dotfiles; }

@test "30-waybar: sends SIGUSR2 when waybar is present" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/30-waybar.sh" nord
  [ "$status" -eq 0 ]
  grep -q 'pkill -SIGUSR2 waybar' "$THEME_SWITCH_TEST_LOG" || grep -q 'pkill -USR2 waybar' "$THEME_SWITCH_TEST_LOG"
}
