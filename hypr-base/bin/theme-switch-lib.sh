# shellcheck shell=bash
# theme-switch-lib.sh — shared helpers

: "${THEME_SWITCH_ROOT:=$HOME/hypr-dots}"
: "${THEME_SWITCH_STATE:=$HOME/.local/state/theme-switch}"

_ts_log_line() { printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$THEME_SWITCH_STATE/log"; }
_ts_err()      { printf 'theme-switch: %s\n' "$*" >&2; _ts_log_line "ERR $*"; }
_ts_info()     { printf 'theme-switch: %s\n' "$*";         _ts_log_line "INFO $*"; }

ts_list_themes() {
  local d
  for d in "$THEME_SWITCH_ROOT"/theme-*/; do
    [ -d "$d" ] || continue
    local base; base=$(basename "${d%/}")
    [ "$base" = "theme-template" ] && continue
    printf '%s\n' "${base#theme-}"
  done
}

ts_current_theme() {
  [ -r "$THEME_SWITCH_STATE/active" ] && cat "$THEME_SWITCH_STATE/active" || echo default
}

ts_meta_value() {
  local theme="$1" key="$2"
  local f="$THEME_SWITCH_ROOT/theme-$theme/meta.toml"
  [ -r "$f" ] || return 1
  awk -F'=' -v k="$key" '
    $1 ~ "^[[:space:]]*"k"[[:space:]]*$" {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      print; exit
    }' "$f"
}
