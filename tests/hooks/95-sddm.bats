#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  mkdir -p "$TMP_ROOT/bin"
  cat > "$TMP_ROOT/bin/pkexec" <<'SEOF'
#!/usr/bin/env bash
echo "pkexec $*" >> "$THEME_SWITCH_TEST_LOG"
exit 0
SEOF
  chmod +x "$TMP_ROOT/bin/pkexec"
  mkdir -p "$TMP_ROOT/usr/local/bin"
  : > "$TMP_ROOT/usr/local/bin/theme-apply-sddm"
  chmod +x "$TMP_ROOT/usr/local/bin/theme-apply-sddm"
  export PATH="$TMP_ROOT/bin:$PATH"
  export TS_SDDM_HELPER="$TMP_ROOT/usr/local/bin/theme-apply-sddm"
}
teardown() { teardown_fake_dotfiles; }

@test "95-sddm: invokes pkexec with helper and theme" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/95-sddm.sh" nord
  [ "$status" -eq 0 ]
  grep -qE "pkexec $TS_SDDM_HELPER nord" "$THEME_SWITCH_TEST_LOG"
}

@test "95-sddm: missing helper is non-fatal" {
  export TS_SDDM_HELPER="$TMP_ROOT/nope"
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/95-sddm.sh" nord
  [ "$status" -eq 0 ]
}
