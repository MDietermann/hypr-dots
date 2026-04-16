# Theme Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a rofi-triggered theme switcher for the Hyprland dotfiles where each theme is a GNU-stow package, missing files fall back to `theme-default`, and running apps hot-reload.

**Architecture:** Dotfiles split into `hypr-base/` (shared) + `theme-<name>/` (per-theme) stow packages under `~/hypr-dots/`. A bash CLI (`theme-switch`) un-stows the current theme, restows `theme-default`, overlays the chosen theme with `stow --override='.*'`, then runs drop-in reload hooks in `bin/theme-hooks.d/`. A rofi front-end (`theme-switch-rofi`) shows a picker with a confirm step. SDDM theme changes go through a polkit-authorized helper at `/usr/local/bin/theme-apply-sddm`.

**Tech Stack:** GNU stow, bash 5+, bats-core (tests), rofi, Hyprland (hyprctl), kitty (remote control over unix socket), waybar (SIGUSR2 reload), nvim (--server/--remote-send), gsettings (GTK), polkit + pkexec, Docker (integration test), GitHub Actions (CI).

**Spec:** `docs/superpowers/specs/2026-04-16-theme-switcher-design.md`

---

## File Structure

### Created

```
~/hypr-dots/
  hypr-base/                                       (stow pkg)
    bin/
      theme-switch                                 main CLI
      theme-switch-rofi                            rofi front-end
      theme-switch-lib.sh                          shared bash functions
      theme-hooks.d/
        10-hyprland.sh
        15-hyprpaper.sh
        20-kitty.sh
        30-waybar.sh
        50-nvim.sh
        60-gtk.sh
        70-cursor.sh
        80-zsh.sh
        95-sddm.sh
    .config/
      theme-switch/manifest.txt                    paths a theme owns
      rofi/applets/type-5/theme-switch.rasi        rofi style
    .local/share/theme-switch/README.md            notes for future you

  theme-default/                                   (stow pkg) fallback
    meta.toml
    .config/hypr/hyprland/look_and_feel.conf       (moved)
    .config/hypr/hyprlock.conf                     (moved)
    .config/hypr/hyprpaper.conf                    (moved+edited)
    .config/kitty/kitty.conf                       (moved; base parts carved out)
    .config/waybar/config                          (moved)
    .config/waybar/style.css                       (moved)
    .config/rofi/colors/colors.rasi                (moved)
    .config/rofi/launchers/type-1/shared/colors.rasi (moved)
    .config/rofi/applets/shared/colors.rasi        (moved)
    .config/rofi/powermenu/type-1/shared/colors.rasi (moved)
    .config/nvim/lua/plugins/colorscheme.lua       (moved)
    .config/gtk-3.0/settings.ini                   (new)
    .config/gtk-4.0/settings.ini                   (new)
    .local/share/wallpapers/default.png            (copied from Viking_Rune.png)
    .local/share/zsh/theme-colors.zsh              (new)
    usr/share/sddm/themes/default/                 (optional; empty for now)

  theme-nord/                                      (stow pkg) overlay
    meta.toml
    .config/ ... (only files that differ)
    .local/share/wallpapers/nord.png

  theme-dracula/                                   (stow pkg) overlay
    meta.toml
    .config/ ... (only files that differ)
    .local/share/wallpapers/dracula.png

  theme-template/                                  NOT stowed; cp-to-create
    README.md
    meta.toml                                      with placeholder values
    .config/ ... (same layout as theme-default with blanked colors)

  install/                                         NOT stowed; tracked
    theme-apply-sddm                               helper script (chmod 0755)
    org.marvin.theme-switch.policy                 polkit action XML
    install.sh                                     idempotent installer

  state/                                           NOT stowed; .gitignore'd
    .gitkeep
  .gitignore                                       adds state/active, state/previous, state/lock, state/log

  tests/
    helpers.bash                                   bats helpers: mktemp, fake HOME
    stubs/                                         stub binaries (hyprctl, gsettings, ...)
    theme-switch.bats
    hooks/
      10-hyprland.bats
      15-hyprpaper.bats
      20-kitty.bats
      30-waybar.bats
      50-nvim.bats
      60-gtk.bats
      70-cursor.bats
      80-zsh.bats
      95-sddm.bats
    integration/
      Dockerfile
      run.sh
    manual-smoke.md

  .github/workflows/test.yml                       CI
```

### Modified

- `hypr-base/.config/hypr/hyprland/keybinds.conf` — add `bind = $mainMod, T, exec, ~/bin/theme-switch-rofi`
- `hypr-base/.config/kitty/kitty.conf` — add `allow_remote_control socket-only` + `listen_on unix:/tmp/kitty-{kitty_pid}`
- `hypr-base/.config/nvim/lua/config/options.lua` — add `vim.fn.serverstart(...)` call
- `hypr-base/.zshrc` — add source of `~/.local/share/zsh/theme-colors.zsh` + precmd hook

### Moved (out of current flat layout, into `hypr-base/` or `theme-default/`)

Shared (to `hypr-base/`): `hyprland.conf`, `hypridle.conf`, `hyprland/{keybinds,programs,input,autostart,window_and_workspaces}.conf`, `Viking_Rune.png`, all `rofi/applets/`, `rofi/launchers/`, `rofi/powermenu/`, `rofi/images/`, all of `nvim/` **except** `nvim/lua/plugins/colorscheme.lua`, `.zshrc`.

Per-theme (to `theme-default/`): `hyprland/look_and_feel.conf`, `hyprlock.conf`, `hyprpaper.conf`, `kitty/kitty.conf`, `waybar/config`, `waybar/style.css`, `rofi/colors/colors.rasi`, the three `rofi/**/shared/colors.rasi` files, `nvim/lua/plugins/colorscheme.lua`.

---

## Phase 0 — Prep & test infrastructure

### Task 0.1: Install bats-core

**Files:** none (system package)

- [ ] **Step 1:** Install bats.

Run: `sudo pacman -S --needed bats`
Expected: bats is installed (or already present).

- [ ] **Step 2:** Verify.

Run: `bats --version`
Expected: prints `Bats 1.x.x`.

### Task 0.2: Create working branch

**Files:** none (git branch)

- [ ] **Step 1:** Ensure clean stash of unrelated WIP. Do NOT commit the existing modifications. Stash them.

Run:
```bash
cd ~/hypr-dots
git stash push -m "wip pre-theme-switcher" -- \
  .config/hypr/hyprland/autostart.conf \
  .config/hypr/hyprland/keybinds.conf \
  .config/hypr/hyprland/window_and_workspaces.conf \
  .config/nvim/lazy-lock.json \
  .config/nvim/lazyvim.json \
  .config/rofi/applets/bin/volume.sh \
  .zshrc \
  .config/nvim/lua/plugins/colorscheme.lua \
  .config/nvim/lua/plugins/dashboard.lua
```
Expected: stash saved; `git status` is clean.

- [ ] **Step 2:** Create and checkout branch.

Run: `git checkout -b theme-switcher`
Expected: switched to new branch.

### Task 0.3: Create `tests/helpers.bash`

**Files:**
- Create: `tests/helpers.bash`

- [ ] **Step 1:** Write helpers.

```bash
# tests/helpers.bash — sourced by every .bats file

setup_fake_dotfiles() {
  TMP_ROOT=$(mktemp -d)
  export HOME="$TMP_ROOT/home"
  export STOW_DIR="$HOME/hypr-dots"
  mkdir -p "$STOW_DIR" "$HOME/.config" "$HOME/.local/state/theme-switch"
  # Point PATH at the real hypr-base/bin from the repo under test:
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."
  export PATH="$REPO_ROOT/hypr-base/bin:$REPO_ROOT/tests/stubs:$PATH"
  # Make the CLI see our temp stow dir:
  export THEME_SWITCH_ROOT="$STOW_DIR"
}

teardown_fake_dotfiles() {
  [ -n "${TMP_ROOT:-}" ] && rm -rf "$TMP_ROOT"
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
```

- [ ] **Step 2:** Commit.

```bash
git add tests/helpers.bash
git commit -m "tests: add bats helpers for fake dotfiles root"
```

### Task 0.4: Create `tests/stubs/` with trackable fake binaries

**Files:**
- Create: `tests/stubs/hyprctl`
- Create: `tests/stubs/gsettings`
- Create: `tests/stubs/notify-send`
- Create: `tests/stubs/pkexec`
- Create: `tests/stubs/kitten`
- Create: `tests/stubs/magick`
- Create: `tests/stubs/rofi`

- [ ] **Step 1:** Write one generic stub template, then copy it. The stub appends its argv to a log file so tests can assert invocation.

`tests/stubs/_stub_template` (reference only; each stub is a copy):

```bash
#!/usr/bin/env bash
tool=$(basename "$0")
log="${THEME_SWITCH_TEST_LOG:-/tmp/theme-switch-test-calls.log}"
printf '%s %q ' "$tool" "$(date +%s%N)" >> "$log"
printf '%q ' "$@" >> "$log"
printf '\n' >> "$log"
exit 0
```

- [ ] **Step 2:** Create each stub as a copy with `chmod +x`.

```bash
mkdir -p tests/stubs
for t in hyprctl gsettings notify-send pkexec kitten magick rofi; do
  cat > "tests/stubs/$t" <<'EOF'
#!/usr/bin/env bash
tool=$(basename "$0")
log="${THEME_SWITCH_TEST_LOG:-/tmp/theme-switch-test-calls.log}"
{
  printf '%s' "$tool"
  for a in "$@"; do printf ' %q' "$a"; done
  printf '\n'
} >> "$log"
exit 0
EOF
  chmod +x "tests/stubs/$t"
done
```

- [ ] **Step 3:** Commit.

```bash
git add tests/stubs/
git commit -m "tests: add stub binaries for hook tests"
```

---

## Phase 1 — Dotfiles migration (one-time)

> Safety: through all of Phase 1 the live system keeps working because the old flat stow tree stays stowed. We only move files **inside** `hypr-dots/` — the live symlinks still resolve because we use `git mv` which preserves inode contents and the symlinks from `~/.config` point at absolute paths that resolve to the same files via git history… **actually no**. The live symlinks point at `~/hypr-dots/.config/<x>`. If we `git mv` those files into `hypr-dots/hypr-base/.config/<x>`, the live symlinks break.
>
> **Correct safety procedure:** do the reorg inside a **new subdirectory** (`hypr-dots/hypr-base/`), keep the old flat paths intact while you stage files with `cp`, finish the new structure, then in Task 1.18 atomically un-stow old + stow new. Only then remove the old flat copies.

### Task 1.1: Scaffold `hypr-base/` and `theme-default/`

**Files:**
- Create: `hypr-base/` (empty dirs)
- Create: `theme-default/` (empty dirs)

- [ ] **Step 1:** Make skeletons.

```bash
cd ~/hypr-dots
mkdir -p hypr-base/.config/hypr/hyprland
mkdir -p hypr-base/.config/rofi
mkdir -p hypr-base/.config/nvim
mkdir -p hypr-base/.config/theme-switch
mkdir -p hypr-base/.config/kitty
mkdir -p hypr-base/bin/theme-hooks.d

mkdir -p theme-default/.config/hypr/hyprland
mkdir -p theme-default/.config/kitty
mkdir -p theme-default/.config/waybar
mkdir -p theme-default/.config/rofi/colors
mkdir -p theme-default/.config/rofi/launchers/type-1/shared
mkdir -p theme-default/.config/rofi/applets/shared
mkdir -p theme-default/.config/rofi/powermenu/type-1/shared
mkdir -p theme-default/.config/nvim/lua/plugins
mkdir -p theme-default/.config/gtk-3.0
mkdir -p theme-default/.config/gtk-4.0
mkdir -p theme-default/.local/share/wallpapers
mkdir -p theme-default/.local/share/zsh
mkdir -p theme-default/usr/share/sddm/themes/default
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base theme-default
git commit -m "scaffold: hypr-base and theme-default skeletons"
```

### Task 1.2: Copy shared hypr configs into `hypr-base/`

**Files:**
- Create (copy from): `hypr-base/.config/hypr/hyprland.conf`
- Create: `hypr-base/.config/hypr/hypridle.conf`
- Create: `hypr-base/.config/hypr/hyprland/keybinds.conf`
- Create: `hypr-base/.config/hypr/hyprland/programs.conf`
- Create: `hypr-base/.config/hypr/hyprland/input.conf`
- Create: `hypr-base/.config/hypr/hyprland/autostart.conf`
- Create: `hypr-base/.config/hypr/hyprland/window_and_workspaces.conf`
- Create: `hypr-base/.config/hypr/Viking_Rune.png`

- [ ] **Step 1:** Copy (keep old flat tree intact for now).

```bash
cd ~/hypr-dots
cp .config/hypr/hyprland.conf      hypr-base/.config/hypr/
cp .config/hypr/hypridle.conf      hypr-base/.config/hypr/
cp .config/hypr/hyprland/keybinds.conf          hypr-base/.config/hypr/hyprland/
cp .config/hypr/hyprland/programs.conf          hypr-base/.config/hypr/hyprland/
cp .config/hypr/hyprland/input.conf             hypr-base/.config/hypr/hyprland/
cp .config/hypr/hyprland/autostart.conf         hypr-base/.config/hypr/hyprland/
cp .config/hypr/hyprland/window_and_workspaces.conf hypr-base/.config/hypr/hyprland/
cp .config/hypr/Viking_Rune.png    hypr-base/.config/hypr/
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/.config/hypr
git commit -m "migrate: copy shared hypr configs into hypr-base"
```

### Task 1.3: Copy shared rofi assets into `hypr-base/`

**Files:**
- Create: `hypr-base/.config/rofi/applets/**`
- Create: `hypr-base/.config/rofi/launchers/**`
- Create: `hypr-base/.config/rofi/powermenu/**`
- Create: `hypr-base/.config/rofi/images/**`

- [ ] **Step 1:** Copy shared (scripts, images, non-color rasi).

```bash
cd ~/hypr-dots
cp -a .config/rofi/applets    hypr-base/.config/rofi/
cp -a .config/rofi/launchers  hypr-base/.config/rofi/
cp -a .config/rofi/powermenu  hypr-base/.config/rofi/
cp -a .config/rofi/images     hypr-base/.config/rofi/
```

- [ ] **Step 2:** Delete files that are per-theme (they move to theme-default in Task 1.13).

```bash
rm hypr-base/.config/rofi/applets/shared/colors.rasi
rm hypr-base/.config/rofi/launchers/type-1/shared/colors.rasi
rm hypr-base/.config/rofi/powermenu/type-1/shared/colors.rasi
```

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/.config/rofi
git commit -m "migrate: copy shared rofi assets (applets, launchers, powermenu, images) into hypr-base"
```

### Task 1.4: Copy nvim into `hypr-base/` (minus colorscheme plugin)

**Files:**
- Create: `hypr-base/.config/nvim/**`

- [ ] **Step 1:** Copy.

```bash
cd ~/hypr-dots
cp -a .config/nvim/. hypr-base/.config/nvim/
```

- [ ] **Step 2:** Remove the colorscheme plugin (goes to theme-default in Task 1.16).

```bash
rm -f hypr-base/.config/nvim/lua/plugins/colorscheme.lua
```

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/.config/nvim
git commit -m "migrate: copy nvim into hypr-base (sans colorscheme plugin)"
```

### Task 1.5: Copy `.zshrc` into `hypr-base/`

**Files:**
- Create: `hypr-base/.zshrc`

- [ ] **Step 1:** Copy.

```bash
cd ~/hypr-dots
cp .zshrc hypr-base/.zshrc
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/.zshrc
git commit -m "migrate: copy .zshrc into hypr-base"
```

### Task 1.6: Add kitty remote-control settings

**Files:**
- Modify: `hypr-base/.config/kitty/kitty.conf` — but this file doesn't yet live in hypr-base. The current kitty.conf is shared (no per-theme part); we'll split: base settings stay in hypr-base, color settings move to theme-default. For this task, first copy the real kitty.conf into hypr-base, then append remote-control directives.

- [ ] **Step 1:** Copy kitty.conf into hypr-base.

```bash
cd ~/hypr-dots
cp .config/kitty/kitty.conf hypr-base/.config/kitty/kitty.conf
```

- [ ] **Step 2:** Append remote-control directives.

```bash
cat >> hypr-base/.config/kitty/kitty.conf <<'EOF'

# --- theme-switch integration ---
allow_remote_control socket-only
listen_on unix:/tmp/kitty-{kitty_pid}
EOF
```

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/.config/kitty
git commit -m "kitty: enable remote control for theme-switch"
```

### Task 1.7: Add nvim `serverstart` call

**Files:**
- Modify: `hypr-base/.config/nvim/lua/config/options.lua`

- [ ] **Step 1:** Append.

```bash
cat >> hypr-base/.config/nvim/lua/config/options.lua <<'EOF'

-- theme-switch integration: advertise a nvim server per pid
local sock = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-" .. vim.fn.getpid()
pcall(vim.fn.serverstart, sock)
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/.config/nvim/lua/config/options.lua
git commit -m "nvim: open a per-pid server socket for theme-switch hook"
```

### Task 1.8: Add `.zshrc` hook for theme colors

**Files:**
- Modify: `hypr-base/.zshrc`

- [ ] **Step 1:** Append.

```bash
cat >> hypr-base/.zshrc <<'EOF'

# --- theme-switch integration ---
_theme_colors_file="$HOME/.local/share/zsh/theme-colors.zsh"
_theme_colors_marker="$HOME/.local/state/theme-switch/zsh-marker"
[ -f "$_theme_colors_file" ] && source "$_theme_colors_file"
_theme_colors_precmd() {
  [ -f "$_theme_colors_marker" ] || return 0
  local mtime
  mtime=$(stat -c %Y "$_theme_colors_marker" 2>/dev/null) || return 0
  if [ "$mtime" != "${_theme_colors_seen:-}" ]; then
    [ -f "$_theme_colors_file" ] && source "$_theme_colors_file"
    _theme_colors_seen="$mtime"
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _theme_colors_precmd
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/.zshrc
git commit -m "zsh: source theme-colors.zsh and re-source on switch"
```

### Task 1.9: Copy per-theme hypr files into `theme-default/`

**Files:**
- Create: `theme-default/.config/hypr/hyprland/look_and_feel.conf`
- Create: `theme-default/.config/hypr/hyprlock.conf`
- Create: `theme-default/.config/hypr/hyprpaper.conf`

- [ ] **Step 1:** Copy.

```bash
cd ~/hypr-dots
cp .config/hypr/hyprland/look_and_feel.conf theme-default/.config/hypr/hyprland/
cp .config/hypr/hyprlock.conf               theme-default/.config/hypr/
cp .config/hypr/hyprpaper.conf              theme-default/.config/hypr/
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.config/hypr
git commit -m "migrate: copy per-theme hypr configs into theme-default"
```

### Task 1.10: Copy wallpaper and rewrite `hyprpaper.conf`

**Files:**
- Create: `theme-default/.local/share/wallpapers/default.png`
- Modify: `theme-default/.config/hypr/hyprpaper.conf`

- [ ] **Step 1:** Copy wallpaper under the theme.

```bash
cd ~/hypr-dots
cp hypr-base/.config/hypr/Viking_Rune.png theme-default/.local/share/wallpapers/default.png
```

- [ ] **Step 2:** Rewrite `hyprpaper.conf` to reference the new path.

```bash
cat > theme-default/.config/hypr/hyprpaper.conf <<'EOF'
preload = ~/.local/share/wallpapers/default.png
wallpaper = , ~/.local/share/wallpapers/default.png
splash = false
EOF
```

- [ ] **Step 3:** Commit.

```bash
git add theme-default/.local/share/wallpapers theme-default/.config/hypr/hyprpaper.conf
git commit -m "theme-default: bundle wallpaper and rewrite hyprpaper.conf path"
```

### Task 1.11: Copy per-theme kitty.conf colors

**Files:**
- Create: `theme-default/.config/kitty/kitty.conf`

> Approach: kitty.conf mixes base + colors. For simplicity in this first migration we keep a single kitty.conf per theme: the theme's kitty.conf is the **full** file, and hypr-base does NOT ship a kitty.conf. Overlaying a theme thus fully determines kitty. The remote-control directives from Task 1.6 move into each theme's kitty.conf.

- [ ] **Step 1:** Copy the modified hypr-base kitty.conf into theme-default.

```bash
cd ~/hypr-dots
cp hypr-base/.config/kitty/kitty.conf theme-default/.config/kitty/kitty.conf
```

- [ ] **Step 2:** Remove kitty from hypr-base (it lives per-theme now).

```bash
git rm -r hypr-base/.config/kitty
```

- [ ] **Step 3:** Commit.

```bash
git add theme-default/.config/kitty hypr-base/.config/kitty
git commit -m "migrate: kitty.conf lives per-theme (includes remote-control block)"
```

### Task 1.12: Copy waybar config + style

**Files:**
- Create: `theme-default/.config/waybar/config`
- Create: `theme-default/.config/waybar/style.css`

- [ ] **Step 1:** Copy.

```bash
cd ~/hypr-dots
cp .config/waybar/config    theme-default/.config/waybar/
cp .config/waybar/style.css theme-default/.config/waybar/
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.config/waybar
git commit -m "theme-default: bundle waybar config and style"
```

### Task 1.13: Copy rofi color files

**Files:**
- Create: `theme-default/.config/rofi/colors/colors.rasi`
- Create: `theme-default/.config/rofi/launchers/type-1/shared/colors.rasi`
- Create: `theme-default/.config/rofi/applets/shared/colors.rasi`
- Create: `theme-default/.config/rofi/powermenu/type-1/shared/colors.rasi`

- [ ] **Step 1:** Copy.

```bash
cd ~/hypr-dots
cp .config/rofi/colors/colors.rasi                          theme-default/.config/rofi/colors/
cp .config/rofi/launchers/type-1/shared/colors.rasi         theme-default/.config/rofi/launchers/type-1/shared/
cp .config/rofi/applets/shared/colors.rasi                  theme-default/.config/rofi/applets/shared/
cp .config/rofi/powermenu/type-1/shared/colors.rasi         theme-default/.config/rofi/powermenu/type-1/shared/
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.config/rofi
git commit -m "theme-default: bundle rofi colors (4 files)"
```

### Task 1.14: Copy nvim colorscheme plugin

**Files:**
- Create: `theme-default/.config/nvim/lua/plugins/colorscheme.lua`

- [ ] **Step 1:** Copy if it exists in the old tree; otherwise synthesize a default that picks the stock LazyVim colorscheme.

```bash
cd ~/hypr-dots
if [ -f .config/nvim/lua/plugins/colorscheme.lua ]; then
  cp .config/nvim/lua/plugins/colorscheme.lua theme-default/.config/nvim/lua/plugins/colorscheme.lua
else
  cat > theme-default/.config/nvim/lua/plugins/colorscheme.lua <<'EOF'
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}
EOF
fi
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.config/nvim
git commit -m "theme-default: bundle nvim colorscheme plugin"
```

### Task 1.15: Create GTK settings files

**Files:**
- Create: `theme-default/.config/gtk-3.0/settings.ini`
- Create: `theme-default/.config/gtk-4.0/settings.ini`

- [ ] **Step 1:** Write.

```bash
cat > theme-default/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOF
cp theme-default/.config/gtk-3.0/settings.ini theme-default/.config/gtk-4.0/settings.ini
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.config/gtk-3.0 theme-default/.config/gtk-4.0
git commit -m "theme-default: GTK settings.ini"
```

### Task 1.16: Create `theme-colors.zsh` for default theme

**Files:**
- Create: `theme-default/.local/share/zsh/theme-colors.zsh`

- [ ] **Step 1:** Write a minimal default palette hook (exports LS_COLORS-style overrides or prompt color vars). Keep it harmless when unused.

```bash
cat > theme-default/.local/share/zsh/theme-colors.zsh <<'EOF'
# theme-default palette (consumed by prompt/plugins as they see fit)
export THEME_NAME="default"
export THEME_ACCENT="#33ccff"
export THEME_BG="#1a1a1a"
export THEME_FG="#ffffff"
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/.local/share/zsh
git commit -m "theme-default: zsh color exports"
```

### Task 1.17: Author `theme-default/meta.toml`

**Files:**
- Create: `theme-default/meta.toml`

- [ ] **Step 1:** Write.

```bash
cat > theme-default/meta.toml <<'EOF'
name          = "Default"
description   = "Viking · cyan & green"
accent        = "#33ccff"
preview       = ".local/share/wallpapers/default.png"
colorscheme   = "tokyonight"
gtk_theme     = "Adwaita-dark"
icon_theme    = "Adwaita"
cursor_theme  = "Adwaita"
cursor_size   = 24
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add theme-default/meta.toml
git commit -m "theme-default: meta.toml"
```

### Task 1.18: Add `.gitignore` for `state/`

**Files:**
- Create: `.gitignore` (or modify existing)
- Create: `state/.gitkeep`

- [ ] **Step 1:** Ensure gitignore.

```bash
cd ~/hypr-dots
mkdir -p state
touch state/.gitkeep
cat >> .gitignore <<'EOF'

# theme-switch runtime state
state/active
state/previous
state/lock
state/log
state/log.1
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add .gitignore state/.gitkeep
git commit -m "theme-switch: ignore runtime state files"
```

### Task 1.19: Un-stow old tree, stow new packages, verify

**Files:** none (live stow operation)

> **Live-system danger:** this step re-points your live symlinks. If it fails mid-way, your Hyprland session can break. Have a TTY handy (`Ctrl+Alt+F3`) before running.

- [ ] **Step 1:** Verify new packages stow cleanly in dry-run.

```bash
cd ~/hypr-dots
stow --no --verbose=2 hypr-base 2>&1 | head -40
stow --no --verbose=2 theme-default 2>&1 | head -40
```
Expected: no fatal conflicts. Non-symlink conflicts (e.g. `~/.config/kitty/kitty.conf` is currently a symlink to the old flat tree; that's fine) are OK.

- [ ] **Step 2:** Un-stow the old flat hypr-dots package, then delete the old flat copies.

```bash
cd ~
stow -D hypr-dots              # removes ALL old symlinks under ~/.config
cd ~/hypr-dots
git rm -r .config .zshrc Viking_Rune.png 2>/dev/null || true
git commit -m "migrate: drop flat layout now that packages exist"
```

- [ ] **Step 3:** Stow the new packages.

```bash
cd ~
stow -d hypr-dots hypr-base theme-default
```
Expected: symlinks created in `~/.config/*`, `~/bin/`, `~/.local/share/*`, `~/.zshrc`.

- [ ] **Step 4:** Reload Hyprland.

Run: `hyprctl reload`
Expected: session continues; waybar restarts; kitty picks up on next launch.

- [ ] **Step 5:** Persist initial state.

```bash
mkdir -p ~/.local/state/theme-switch
echo default > ~/.local/state/theme-switch/active
```

- [ ] **Step 6:** Commit (of the branch — nothing to commit if step 2 already committed; this is a sanity step).

```bash
git status --short
```
Expected: clean.

---

## Phase 2 — Core switcher CLI (TDD)

### Task 2.1: Create `theme-switch-lib.sh` and skeleton `theme-switch`

**Files:**
- Create: `hypr-base/bin/theme-switch-lib.sh`
- Create: `hypr-base/bin/theme-switch`

- [ ] **Step 1:** Write the lib (env + helpers, no commands yet).

```bash
cat > hypr-base/bin/theme-switch-lib.sh <<'EOF'
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
EOF
```

- [ ] **Step 2:** Write the skeleton CLI.

```bash
cat > hypr-base/bin/theme-switch <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
# shellcheck source=./theme-switch-lib.sh
source "$HERE/theme-switch-lib.sh"

mkdir -p "$THEME_SWITCH_STATE"

cmd="${1:-}"
case "$cmd" in
  --list)     ts_list_themes; exit 0 ;;
  --current)  ts_current_theme; exit 0 ;;
  --dry-run)  shift; _ts_err "not implemented"; exit 2 ;;
  --rollback) _ts_err "not implemented"; exit 2 ;;
  "")         _ts_err "usage: theme-switch <name|--list|--current|--dry-run NAME|--rollback>"; exit 2 ;;
  -*)         _ts_err "unknown option: $cmd"; exit 2 ;;
  *)          _ts_err "apply not yet implemented"; exit 2 ;;
esac
EOF
chmod +x hypr-base/bin/theme-switch
```

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/bin/theme-switch hypr-base/bin/theme-switch-lib.sh
git commit -m "theme-switch: add CLI skeleton with --list and --current"
```

### Task 2.2: TDD `--list`

**Files:**
- Create: `tests/theme-switch.bats`

- [ ] **Step 1:** Write the failing test.

```bash
cat > tests/theme-switch.bats <<'EOF'
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
EOF
```

- [ ] **Step 2:** Run the test.

Run: `bats tests/theme-switch.bats`
Expected: PASS (implementation already exists from skeleton — this test locks behavior).

- [ ] **Step 3:** Commit.

```bash
git add tests/theme-switch.bats
git commit -m "test: theme-switch --list"
```

### Task 2.3: TDD `--current`

**Files:**
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Add test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

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
EOF
```

- [ ] **Step 2:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS for all 3 tests.

- [ ] **Step 3:** Commit.

```bash
git add tests/theme-switch.bats
git commit -m "test: theme-switch --current"
```

### Task 2.4: TDD theme validation

**Files:**
- Modify: `hypr-base/bin/theme-switch`
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

@test "apply: unknown theme exits 1 with helpful message" {
  make_fake_theme default
  run theme-switch foo
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"not found"* || "$output" == *"not found"* ]]
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL (current skeleton returns 2 from "*) case).

Run: `bats tests/theme-switch.bats`
Expected: failure on the new test.

- [ ] **Step 3:** Implement.

Replace the `*)` case in `hypr-base/bin/theme-switch` with:

```bash
  *)
    new="$cmd"
    if [ ! -d "$THEME_SWITCH_ROOT/theme-$new" ] || [ "$new" = "template" ]; then
      available=$(ts_list_themes | paste -sd ' ')
      _ts_err "theme '$new' not found. available: $available"
      exit 1
    fi
    _ts_err "apply flow not yet implemented"; exit 2 ;;
```

- [ ] **Step 4:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS.

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-switch tests/theme-switch.bats
git commit -m "theme-switch: validate theme name; reject unknown and 'template'"
```

### Task 2.5: TDD `--dry-run`

**Files:**
- Modify: `hypr-base/bin/theme-switch`
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/theme-switch.bats`

- [ ] **Step 3:** Implement.

In `theme-switch`, replace the `--dry-run` case:

```bash
  --dry-run)
    shift
    new="${1:-}"
    [ -n "$new" ] || { _ts_err "--dry-run requires a theme name"; exit 2; }
    [ -d "$THEME_SWITCH_ROOT/theme-$new" ] || { _ts_err "theme '$new' not found"; exit 1; }
    active=$(ts_current_theme)
    echo "PLAN:"
    echo "  stow -D theme-$active"
    echo "  stow -R theme-default"
    [ "$new" != "default" ] && echo "  stow --override='.*' theme-$new"
    echo "  run hooks: $(ls "$(dirname "$0")"/theme-hooks.d/*.sh 2>/dev/null | xargs -n1 basename | paste -sd ' ')"
    exit 0 ;;
```

- [ ] **Step 4:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS.

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-switch tests/theme-switch.bats
git commit -m "theme-switch: --dry-run prints plan without mutation"
```

### Task 2.6: TDD apply flow

**Files:**
- Modify: `hypr-base/bin/theme-switch`
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Write failing test for apply.

```bash
cat >> tests/theme-switch.bats <<'EOF'

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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/theme-switch.bats`

- [ ] **Step 3:** Implement apply.

Replace the trailing failing `*)` branch in `theme-switch` with:

```bash
  *)
    new="$cmd"
    if [ ! -d "$THEME_SWITCH_ROOT/theme-$new" ] || [ "$new" = "template" ]; then
      available=$(ts_list_themes | paste -sd ' ')
      _ts_err "theme '$new' not found. available: $available"
      exit 1
    fi

    mkdir -p "$THEME_SWITCH_STATE"
    exec 200>"$THEME_SWITCH_STATE/lock"
    flock -n 200 || { _ts_err "theme-switch already running"; exit 1; }

    active=$(ts_current_theme)

    trap '_ts_err "switch failed; reverting to default"; ( cd "$THEME_SWITCH_ROOT" && stow -R theme-default -t "$HOME" ) || true; exit 1' ERR

    (
      cd "$THEME_SWITCH_ROOT"
      stow -D "theme-$active" -t "$HOME" 2>/dev/null || true
      stow -R theme-default -t "$HOME"
      if [ "$new" != "default" ]; then
        stow --override='.*' "theme-$new" -t "$HOME"
      fi
    )

    echo "$active" > "$THEME_SWITCH_STATE/previous"
    echo "$new"    > "$THEME_SWITCH_STATE/active"
    _ts_info "applied theme: $new (from $active)"

    hookdir="$HERE/theme-hooks.d"
    failed_hooks=()
    if [ -d "$hookdir" ]; then
      for h in "$hookdir"/*.sh; do
        [ -r "$h" ] || continue
        if ! bash "$h" "$new"; then
          failed_hooks+=("$(basename "$h")")
          _ts_err "hook failed: $(basename "$h")"
        fi
      done
    fi

    if [ "${#failed_hooks[@]}" -gt 0 ]; then
      _ts_err "applied with ${#failed_hooks[@]} hook failures: ${failed_hooks[*]}"
    fi

    command -v notify-send >/dev/null && notify-send "theme-switch" "applied: $new" || true
    exit 0 ;;
```

- [ ] **Step 4:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS.

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-switch tests/theme-switch.bats
git commit -m "theme-switch: implement apply flow (stow + hook runner + state)"
```

### Task 2.7: TDD flock (concurrent guard)

**Files:**
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Add test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

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
EOF
```

- [ ] **Step 2:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS (implementation from Task 2.6 already has flock).

- [ ] **Step 3:** Commit.

```bash
git add tests/theme-switch.bats
git commit -m "test: theme-switch concurrent lock"
```

### Task 2.8: TDD hook runner and hook failure isolation

**Files:**
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Add test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

@test "hooks: drop-in hook receives theme name as $1" {
  make_fake_theme default
  make_fake_theme nord
  ( cd "$STOW_DIR" && stow -t "$HOME" theme-default )
  echo default > "$HOME/.local/state/theme-switch/active"

  local hookdir="$REPO_ROOT/hypr-base/bin/theme-hooks.d"
  local marker="$HOME/hook-ran"
  cat > "$hookdir/99-test.sh" <<HEOF
#!/usr/bin/env bash
echo "\$1" > "$marker"
HEOF
  chmod +x "$hookdir/99-test.sh"

  run theme-switch nord
  rm -f "$hookdir/99-test.sh"

  [ "$status" -eq 0 ]
  [ -f "$marker" ]
  [ "$(cat "$marker")" = "nord" ]
}

@test "hooks: a failing hook is logged but doesn't abort the switch" {
  make_fake_theme default
  make_fake_theme nord
  ( cd "$STOW_DIR" && stow -t "$HOME" theme-default )
  echo default > "$HOME/.local/state/theme-switch/active"

  local hookdir="$REPO_ROOT/hypr-base/bin/theme-hooks.d"
  cat > "$hookdir/98-fail.sh" <<'HEOF'
#!/usr/bin/env bash
exit 7
HEOF
  chmod +x "$hookdir/98-fail.sh"

  run theme-switch nord
  rm -f "$hookdir/98-fail.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"hook failed: 98-fail.sh"* || "$stderr" == *"hook failed: 98-fail.sh"* ]]
  [ "$(cat "$HOME/.local/state/theme-switch/active")" = "nord" ]
}
EOF
```

- [ ] **Step 2:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS.

- [ ] **Step 3:** Commit.

```bash
git add tests/theme-switch.bats
git commit -m "test: theme-switch hook runner and failure isolation"
```

### Task 2.9: TDD `--rollback`

**Files:**
- Modify: `hypr-base/bin/theme-switch`
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Add test.

```bash
cat >> tests/theme-switch.bats <<'EOF'

@test "--rollback restores previous theme" {
  make_fake_theme default
  make_fake_theme nord
  make_fake_theme dracula
  ( cd "$STOW_DIR" && stow -t "$HOME" theme-default )

  echo default > "$HOME/.local/state/theme-switch/active"
  theme-switch nord
  theme-switch dracula

  run theme-switch --rollback
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.local/state/theme-switch/active")" = "nord" ]
}

@test "--rollback without previous fails cleanly" {
  make_fake_theme default
  run theme-switch --rollback
  [ "$status" -eq 1 ]
  [[ "$output" == *"nothing to roll back"* || "$stderr" == *"nothing to roll back"* ]]
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/theme-switch.bats`

- [ ] **Step 3:** Implement.

Replace the `--rollback)` case in `theme-switch`:

```bash
  --rollback)
    prev_file="$THEME_SWITCH_STATE/previous"
    if [ ! -s "$prev_file" ]; then
      _ts_err "nothing to roll back to"
      exit 1
    fi
    prev=$(cat "$prev_file")
    exec "$0" "$prev" ;;
```

- [ ] **Step 4:** Run.

Run: `bats tests/theme-switch.bats`
Expected: PASS.

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-switch tests/theme-switch.bats
git commit -m "theme-switch: --rollback (one level via state/previous)"
```

### Task 2.10: Sanity manifest checker

**Files:**
- Create: `hypr-base/.config/theme-switch/manifest.txt`
- Modify: `hypr-base/bin/theme-switch`
- Modify: `tests/theme-switch.bats`

- [ ] **Step 1:** Write manifest (the paths a theme owns; broken link here means something went wrong).

```bash
cat > hypr-base/.config/theme-switch/manifest.txt <<'EOF'
.config/hypr/hyprland/look_and_feel.conf
.config/hypr/hyprlock.conf
.config/hypr/hyprpaper.conf
.config/kitty/kitty.conf
.config/waybar/config
.config/waybar/style.css
.config/rofi/colors/colors.rasi
.config/rofi/launchers/type-1/shared/colors.rasi
.config/rofi/applets/shared/colors.rasi
.config/rofi/powermenu/type-1/shared/colors.rasi
.config/nvim/lua/plugins/colorscheme.lua
.config/gtk-3.0/settings.ini
.config/gtk-4.0/settings.ini
.local/share/wallpapers
.local/share/zsh/theme-colors.zsh
EOF
```

- [ ] **Step 2:** Add the sanity pass. Append to the apply flow (just before `exit 0`):

```bash
    manifest="$HERE/../.config/theme-switch/manifest.txt"
    [ -f "$manifest" ] || manifest="$HOME/.config/theme-switch/manifest.txt"
    if [ -f "$manifest" ]; then
      broken=()
      while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        p="$HOME/$rel"
        if [ -e "$p" ] || [ -L "$p" ]; then
          if ! readlink -e "$p" >/dev/null 2>&1 && [ -L "$p" ]; then
            broken+=("$rel")
          fi
        fi
      done < "$manifest"
      if [ "${#broken[@]}" -gt 0 ]; then
        _ts_err "manifest warnings (broken links): ${broken[*]}"
      fi
    fi
```

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/.config/theme-switch hypr-base/bin/theme-switch
git commit -m "theme-switch: post-apply manifest sanity pass"
```

---

## Phase 3 — Reload hooks (one per tool)

Each hook follows the same template: check for its tool, exit 0 if absent (logs "skipped"), run its action, exit with that action's status. Tests use the stubs from Task 0.4.

### Task 3.1: `10-hyprland.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/10-hyprland.sh`
- Create: `tests/hooks/10-hyprland.bats`

- [ ] **Step 1:** Write failing test.

```bash
mkdir -p tests/hooks
cat > tests/hooks/10-hyprland.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup()    { setup_fake_dotfiles; export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"; }
teardown() { teardown_fake_dotfiles; }

@test "10-hyprland: calls 'hyprctl reload'" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/10-hyprland.sh" nord
  [ "$status" -eq 0 ]
  grep -qE '^hyprctl reload$' "$THEME_SWITCH_TEST_LOG"
}

@test "10-hyprland: exits 0 when hyprctl absent" {
  PATH=/usr/bin:/bin run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/10-hyprland.sh" nord
  [ "$status" -eq 0 ]
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/10-hyprland.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/10-hyprland.sh <<'EOF'
#!/usr/bin/env bash
set -eu
command -v hyprctl >/dev/null || exit 0
hyprctl reload >/dev/null
EOF
chmod +x hypr-base/bin/theme-hooks.d/10-hyprland.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/10-hyprland.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/10-hyprland.sh tests/hooks/10-hyprland.bats
git commit -m "hook: 10-hyprland reloads Hyprland"
```

### Task 3.2: `15-hyprpaper.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/15-hyprpaper.sh`
- Create: `tests/hooks/15-hyprpaper.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/15-hyprpaper.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/15-hyprpaper.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/15-hyprpaper.sh <<'EOF'
#!/usr/bin/env bash
set -eu
command -v hyprctl >/dev/null || exit 0
conf="$HOME/.config/hypr/hyprpaper.conf"
[ -r "$conf" ] || exit 0
wall=$(awk -F'=' '/^[[:space:]]*preload[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$conf")
[ -n "$wall" ] || exit 0
# expand ~
wall="${wall/#\~/$HOME}"
hyprctl hyprpaper unload all >/dev/null || true
hyprctl hyprpaper preload "$wall" >/dev/null || true
mons=$(hyprctl -j monitors 2>/dev/null | awk -F'"' '/"name":/ {print $4}' || true)
if [ -z "$mons" ]; then
  hyprctl hyprpaper wallpaper ",$wall" >/dev/null || true
else
  for m in $mons; do
    hyprctl hyprpaper wallpaper "$m,$wall" >/dev/null || true
  done
fi
EOF
chmod +x hypr-base/bin/theme-hooks.d/15-hyprpaper.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/15-hyprpaper.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/15-hyprpaper.sh tests/hooks/15-hyprpaper.bats
git commit -m "hook: 15-hyprpaper reloads wallpaper per monitor"
```

### Task 3.3: `20-kitty.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/20-kitty.sh`
- Create: `tests/hooks/20-kitty.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/20-kitty.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup()    { setup_fake_dotfiles; export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"; }
teardown() { teardown_fake_dotfiles; }

@test "20-kitty: no sockets → exits 0, no calls" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  [ "$status" -eq 0 ]
  [ ! -s "$THEME_SWITCH_TEST_LOG" ]
}

@test "20-kitty: sockets present → kitten called once per socket" {
  mkdir -p /tmp/theme-switch-test-sockets
  export KITTY_SOCK_DIR=/tmp/theme-switch-test-sockets
  touch /tmp/kitty-11111 /tmp/kitty-22222
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/20-kitty.sh" nord
  rm -f /tmp/kitty-11111 /tmp/kitty-22222
  [ "$status" -eq 0 ]
  [ "$(grep -c '^kitten' "$THEME_SWITCH_TEST_LOG")" -eq 2 ]
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL on second case.

Run: `bats tests/hooks/20-kitty.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/20-kitty.sh <<'EOF'
#!/usr/bin/env bash
set -eu
command -v kitten >/dev/null || exit 0
kconf="$HOME/.config/kitty/kitty.conf"
[ -r "$kconf" ] || exit 0
shopt -s nullglob
for s in /tmp/kitty-*; do
  [ -S "$s" ] || [ -f "$s" ] || continue
  kitten @ --to "unix:$s" set-colors -a -c "$kconf" >/dev/null 2>&1 || true
done
EOF
chmod +x hypr-base/bin/theme-hooks.d/20-kitty.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/20-kitty.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/20-kitty.sh tests/hooks/20-kitty.bats
git commit -m "hook: 20-kitty applies colors to running sessions"
```

### Task 3.4: `30-waybar.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/30-waybar.sh`
- Create: `tests/hooks/30-waybar.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/30-waybar.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/30-waybar.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/30-waybar.sh <<'EOF'
#!/usr/bin/env bash
set -eu
command -v waybar >/dev/null || exit 0
if pgrep -x waybar >/dev/null 2>&1; then
  pkill -SIGUSR2 waybar || true
else
  nohup waybar >/dev/null 2>&1 &
fi
EOF
chmod +x hypr-base/bin/theme-hooks.d/30-waybar.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

(pgrep may not be stubbed; if the test fails because `pgrep` returns 1, change the implementation to always `pkill -SIGUSR2 waybar || nohup waybar ...`.)

Run: `bats tests/hooks/30-waybar.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/30-waybar.sh tests/hooks/30-waybar.bats
git commit -m "hook: 30-waybar reloads via SIGUSR2 or starts it"
```

### Task 3.5: `50-nvim.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/50-nvim.sh`
- Create: `tests/hooks/50-nvim.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/50-nvim.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/50-nvim.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/50-nvim.sh <<'EOF'
#!/usr/bin/env bash
set -eu
theme="$1"
command -v nvim >/dev/null || exit 0

# Find the colorscheme from theme's meta.toml
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
cs="$theme"
if [ -r "$meta" ]; then
  cs=$(awk -F'=' '/^[[:space:]]*colorscheme[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta") || cs="$theme"
fi

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
shopt -s nullglob
for sock in "$runtime"/nvim-*; do
  nvim --server "$sock" --remote-send ":colorscheme $cs<CR>" >/dev/null 2>&1 || true
done
EOF
chmod +x hypr-base/bin/theme-hooks.d/50-nvim.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/50-nvim.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/50-nvim.sh tests/hooks/50-nvim.bats
git commit -m "hook: 50-nvim sends :colorscheme to running instances"
```

### Task 3.6: `60-gtk.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/60-gtk.sh`
- Create: `tests/hooks/60-gtk.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/60-gtk.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
}
teardown() { teardown_fake_dotfiles; }

@test "60-gtk: sets gtk-theme, icon-theme, cursor-theme from meta.toml" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/60-gtk.sh" nord
  [ "$status" -eq 0 ]
  grep -q 'gsettings set .*gtk-theme' "$THEME_SWITCH_TEST_LOG"
  grep -q 'gsettings set .*icon-theme' "$THEME_SWITCH_TEST_LOG"
  grep -q 'gsettings set .*cursor-theme' "$THEME_SWITCH_TEST_LOG"
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/60-gtk.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/60-gtk.sh <<'EOF'
#!/usr/bin/env bash
set -eu
theme="$1"
command -v gsettings >/dev/null || exit 0
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
[ -r "$meta" ] || exit 0

read_meta() {
  awk -F'=' -v k="$1" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta"
}
gtk=$(read_meta gtk_theme)
icons=$(read_meta icon_theme)
cursor=$(read_meta cursor_theme)

[ -n "$gtk" ]    && gsettings set org.gnome.desktop.interface gtk-theme    "$gtk"    || true
[ -n "$icons" ]  && gsettings set org.gnome.desktop.interface icon-theme   "$icons"  || true
[ -n "$cursor" ] && gsettings set org.gnome.desktop.interface cursor-theme "$cursor" || true
EOF
chmod +x hypr-base/bin/theme-hooks.d/60-gtk.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/60-gtk.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/60-gtk.sh tests/hooks/60-gtk.bats
git commit -m "hook: 60-gtk applies gsettings from meta.toml"
```

### Task 3.7: `70-cursor.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/70-cursor.sh`
- Create: `tests/hooks/70-cursor.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/70-cursor.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  export THEME_SWITCH_TEST_LOG="$TMP_ROOT/calls.log"; : > "$THEME_SWITCH_TEST_LOG"
  make_fake_theme nord
}
teardown() { teardown_fake_dotfiles; }

@test "70-cursor: calls hyprctl setcursor with meta values" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/70-cursor.sh" nord
  [ "$status" -eq 0 ]
  grep -qE 'hyprctl setcursor Adw 24' "$THEME_SWITCH_TEST_LOG"
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/70-cursor.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/70-cursor.sh <<'EOF'
#!/usr/bin/env bash
set -eu
theme="$1"
command -v hyprctl >/dev/null || exit 0
root="${THEME_SWITCH_ROOT:-$HOME/hypr-dots}"
meta="$root/theme-$theme/meta.toml"
[ -r "$meta" ] || exit 0
read_meta() { awk -F'=' -v k="$1" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" { gsub(/^[[:space:]]+|[[:space:]]+$|"/, "", $2); print $2; exit }' "$meta"; }
cursor=$(read_meta cursor_theme); size=$(read_meta cursor_size)
[ -n "$cursor" ] && [ -n "$size" ] && hyprctl setcursor "$cursor" "$size" >/dev/null || true
EOF
chmod +x hypr-base/bin/theme-hooks.d/70-cursor.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/70-cursor.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/70-cursor.sh tests/hooks/70-cursor.bats
git commit -m "hook: 70-cursor calls hyprctl setcursor from meta.toml"
```

### Task 3.8: `80-zsh.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/80-zsh.sh`
- Create: `tests/hooks/80-zsh.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/80-zsh.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup()    { setup_fake_dotfiles; }
teardown() { teardown_fake_dotfiles; }

@test "80-zsh: writes a marker file with mtime" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/80-zsh.sh" nord
  [ "$status" -eq 0 ]
  [ -f "$HOME/.local/state/theme-switch/zsh-marker" ]
}
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/80-zsh.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/80-zsh.sh <<'EOF'
#!/usr/bin/env bash
set -eu
state="${THEME_SWITCH_STATE:-$HOME/.local/state/theme-switch}"
mkdir -p "$state"
: > "$state/zsh-marker"
EOF
chmod +x hypr-base/bin/theme-hooks.d/80-zsh.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/80-zsh.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/80-zsh.sh tests/hooks/80-zsh.bats
git commit -m "hook: 80-zsh signals running shells to re-source theme colors"
```

### Task 3.9: `95-sddm.sh`

**Files:**
- Create: `hypr-base/bin/theme-hooks.d/95-sddm.sh`
- Create: `tests/hooks/95-sddm.bats`

- [ ] **Step 1:** Write failing test.

```bash
cat > tests/hooks/95-sddm.bats <<'EOF'
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
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
EOF
```

- [ ] **Step 2:** Run. Expected: FAIL.

Run: `bats tests/hooks/95-sddm.bats`

- [ ] **Step 3:** Implement.

```bash
cat > hypr-base/bin/theme-hooks.d/95-sddm.sh <<'EOF'
#!/usr/bin/env bash
set -eu
theme="$1"
helper="${TS_SDDM_HELPER:-/usr/local/bin/theme-apply-sddm}"
if command -v pkexec >/dev/null && [ -x "$helper" ]; then
  pkexec "$helper" "$theme" || {
    command -v notify-send >/dev/null && notify-send -u critical "theme-switch" "SDDM update failed" || true
  }
else
  command -v notify-send >/dev/null && notify-send "theme-switch" "SDDM helper missing; run install/install.sh" || true
fi
exit 0
EOF
chmod +x hypr-base/bin/theme-hooks.d/95-sddm.sh
```

- [ ] **Step 4:** Run. Expected: PASS.

Run: `bats tests/hooks/95-sddm.bats`

- [ ] **Step 5:** Commit.

```bash
git add hypr-base/bin/theme-hooks.d/95-sddm.sh tests/hooks/95-sddm.bats
git commit -m "hook: 95-sddm calls polkit helper; non-fatal on missing"
```

---

## Phase 4 — Rofi UI

### Task 4.1: Rofi style file

**Files:**
- Create: `hypr-base/.config/rofi/applets/type-5/theme-switch.rasi`

- [ ] **Step 1:** Write RASI. Import the active colors so the picker itself retints.

```bash
mkdir -p hypr-base/.config/rofi/applets/type-5
cat > hypr-base/.config/rofi/applets/type-5/theme-switch.rasi <<'EOF'
@import "~/.config/rofi/applets/shared/fonts.rasi"
@import "~/.config/rofi/applets/shared/colors.rasi"

* {
    font: "JetBrains Mono 11";
    background-color:  @background;
    text-color:        @foreground;
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    width: 420px;
    border-radius: 10px;
    padding: 12px;
    background-color: @background;
    border: 2px solid;
    border-color: @selected;
}

mainbox { children: [ "inputbar", "listview" ]; spacing: 10px; }
inputbar { children: [ "prompt", "entry" ]; padding: 6px 10px; border-radius: 6px; background-color: @background-alt; }
prompt { text-color: @selected; padding: 0 10px 0 0; }
entry { text-color: @foreground; placeholder: "Pick a theme..."; }
listview { lines: 6; spacing: 4px; cycle: true; }
element { padding: 8px 10px; border-radius: 6px; }
element selected { background-color: @selected; text-color: @background; }
element-icon { size: 20px; padding: 0 10px 0 0; }
element-text { vertical-align: 0.5; }
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/.config/rofi/applets/type-5/theme-switch.rasi
git commit -m "rofi: theme-switch picker style"
```

### Task 4.2: `theme-switch-rofi` script

**Files:**
- Create: `hypr-base/bin/theme-switch-rofi`

- [ ] **Step 1:** Write.

```bash
cat > hypr-base/bin/theme-switch-rofi <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
# shellcheck source=./theme-switch-lib.sh
source "$HERE/theme-switch-lib.sh"

command -v rofi >/dev/null || { theme-switch --list; exit 1; }

style="$HOME/.config/rofi/applets/type-5/theme-switch.rasi"
cache="$HOME/.cache/theme-switch"
mkdir -p "$cache"

current=$(ts_current_theme)
declare -a entries
while IFS= read -r t; do
  desc=$(ts_meta_value "$t" description || echo "")
  accent=$(ts_meta_value "$t" accent || echo "#888")
  icon="$cache/$t.png"
  if [ ! -s "$icon" ] && command -v magick >/dev/null; then
    magick -size 32x32 "xc:$accent" "$icon" >/dev/null 2>&1 || rm -f "$icon"
  fi
  [ -s "$icon" ] || icon=""
  marker=""
  [ "$t" = "$current" ] && marker=" (current)"
  label="$t — $desc$marker"
  entries+=("$label\0icon\x1f$icon")
done < <(ts_list_themes)

pick=$(printf '%b\n' "${entries[@]}" \
       | rofi -dmenu -i -theme "$style" -p "theme" -format s)
[ -n "$pick" ] || exit 0
chosen=$(printf '%s' "$pick" | awk -F' — ' '{print $1}' | tr -d ' ')

confirm=$(printf 'Yes\nNo\n' | rofi -dmenu -i -theme "$style" -p "Apply $chosen?")
[ "$confirm" = "Yes" ] || exit 0

exec theme-switch "$chosen"
EOF
chmod +x hypr-base/bin/theme-switch-rofi
```

- [ ] **Step 2:** Commit.

```bash
git add hypr-base/bin/theme-switch-rofi
git commit -m "rofi: theme-switch-rofi with confirm prompt"
```

---

## Phase 5 — SDDM polkit helper

### Task 5.1: Helper script

**Files:**
- Create: `install/theme-apply-sddm`

- [ ] **Step 1:** Write.

```bash
mkdir -p install
cat > install/theme-apply-sddm <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name="${1:?theme name required}"
# Hard-coded user dotfiles path; adjust if multi-user.
root="/home/marvin/hypr-dots"
[ -d "$root/theme-$name" ] || { printf 'unknown theme: %s\n' "$name" >&2; exit 2; }

if [ -d "$root/theme-$name/usr/share/sddm/themes/$name" ]; then
  rsync -a --delete "$root/theme-$name/usr/share/sddm/themes/$name/" \
                    "/usr/share/sddm/themes/$name/"
fi

mkdir -p /etc/sddm.conf.d
tmp=$(mktemp)
printf '[Theme]\nCurrent=%s\n' "$name" > "$tmp"
install -m 0644 "$tmp" /etc/sddm.conf.d/10-theme.conf
rm -f "$tmp"
EOF
chmod +x install/theme-apply-sddm
```

- [ ] **Step 2:** Commit.

```bash
git add install/theme-apply-sddm
git commit -m "install: theme-apply-sddm helper (runs via polkit)"
```

### Task 5.2: Polkit policy

**Files:**
- Create: `install/org.marvin.theme-switch.policy`

- [ ] **Step 1:** Write.

```bash
cat > install/org.marvin.theme-switch.policy <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD polkit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">
<policyconfig>
  <action id="org.marvin.theme-switch.apply-sddm">
    <description>Apply SDDM theme for theme-switch</description>
    <message>Switch SDDM theme</message>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/theme-apply-sddm</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">false</annotate>
  </action>
</policyconfig>
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add install/org.marvin.theme-switch.policy
git commit -m "install: polkit action for theme-apply-sddm"
```

### Task 5.3: Installer

**Files:**
- Create: `install/install.sh`

- [ ] **Step 1:** Write.

```bash
cat > install/install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")

echo "Installing theme-apply-sddm helper (requires sudo)..."
sudo install -m 0755 "$HERE/theme-apply-sddm" /usr/local/bin/theme-apply-sddm
sudo install -m 0644 "$HERE/org.marvin.theme-switch.policy" \
                     /usr/share/polkit-1/actions/org.marvin.theme-switch.policy
echo "Done."
EOF
chmod +x install/install.sh
```

- [ ] **Step 2:** Commit.

```bash
git add install/install.sh
git commit -m "install: idempotent installer for SDDM helper + polkit"
```

### Task 5.4: Run installer on live system

**Files:** system paths

- [ ] **Step 1:** Run.

```bash
~/hypr-dots/install/install.sh
```
Expected: prints "Done." after sudo prompt.

- [ ] **Step 2:** Verify files present.

```bash
ls -l /usr/local/bin/theme-apply-sddm
ls -l /usr/share/polkit-1/actions/org.marvin.theme-switch.policy
```
Expected: both exist with correct perms.

---

## Phase 6 — Template + alternate themes

### Task 6.1: `theme-template/`

**Files:**
- Create: `theme-template/**` (mirrors theme-default structure)
- Create: `theme-template/README.md`

- [ ] **Step 1:** Seed from theme-default.

```bash
cd ~/hypr-dots
cp -a theme-default theme-template
# Blank palettes
: > theme-template/.local/share/zsh/theme-colors.zsh
cat > theme-template/README.md <<'EOF'
# Theme template

To create a new theme:
    cp -r theme-template theme-<name>
    $EDITOR theme-<name>/meta.toml
    # Edit the color files under theme-<name>/.config/.
    # Replace .local/share/wallpapers/default.png with your wallpaper.
    # Remove any file you don't want to override (it will fall back to theme-default).
EOF
cat > theme-template/meta.toml <<'EOF'
name          = "TEMPLATE"
description   = "fill me in"
accent        = "#888888"
preview       = ".local/share/wallpapers/default.png"
colorscheme   = "tokyonight"
gtk_theme     = "Adwaita-dark"
icon_theme    = "Adwaita"
cursor_theme  = "Adwaita"
cursor_size   = 24
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add theme-template
git commit -m "theme-template: skeleton for creating new themes"
```

### Task 6.2: `theme-nord/`

**Files:**
- Create: `theme-nord/meta.toml`
- Create: `theme-nord/.config/hypr/hyprland/look_and_feel.conf`
- Create: `theme-nord/.config/waybar/style.css`
- Create: `theme-nord/.config/rofi/colors/colors.rasi`
- Create: `theme-nord/.config/kitty/kitty.conf`
- Create: `theme-nord/.local/share/zsh/theme-colors.zsh`
- Create: `theme-nord/.local/share/wallpapers/nord.png` (placeholder solid color)
- Create: `theme-nord/.config/hypr/hyprpaper.conf`

- [ ] **Step 1:** Scaffold from template with Nord palette (`#2e3440`, `#3b4252`, `#434c5e`, `#4c566a`, `#d8dee9`, `#e5e9f0`, `#eceff4`, `#8fbcbb`, `#88c0d0`, `#81a1c1`, `#5e81ac`, `#bf616a`, `#d08770`, `#ebcb8b`, `#a3be8c`, `#b48ead`).

```bash
cd ~/hypr-dots
cp -a theme-template theme-nord
cat > theme-nord/meta.toml <<'EOF'
name          = "Nord"
description   = "arctic blues · polar night"
accent        = "#88c0d0"
preview       = ".local/share/wallpapers/nord.png"
colorscheme   = "nord"
gtk_theme     = "Nordic"
icon_theme    = "Adwaita"
cursor_theme  = "Adwaita"
cursor_size   = 24
EOF

# Hyprland borders & shadow
cat > theme-nord/.config/hypr/hyprland/look_and_feel.conf <<'EOF'
general {
  gaps_in = 4
  gaps_out = 8
  border_size = 2
  col.active_border = rgba(88c0d0ee) rgba(81a1c1ee) 45deg
  col.inactive_border = rgba(3b4252aa)
  resize_on_border = false
  allow_tearing = false
  layout = dwindle
}
decoration {
  rounding = 4
  rounding_power = 2
  active_opacity = 0.92
  inactive_opacity = 0.88
  shadow { enabled = true; range = 4; render_power = 3; color = rgba(2e3440ee) }
  blur { enabled = true; size = 10; passes = 2; vibrancy = 0.12 }
}
EOF

# Waybar (minimal Nord-tinted style.css)
cat > theme-nord/.config/waybar/style.css <<'EOF'
* { font-family: FontAwesome, Roboto, Helvetica, Arial, sans-serif; font-size: 13px; }
window#waybar { background-color: rgba(46, 52, 64, 0.7); color: #eceff4; padding: 4px; }
#workspaces button { color: #d8dee9; padding: 0 6px; }
#workspaces button.active { color: #88c0d0; border-bottom: 2px solid #88c0d0; }
#clock, #network, #pulseaudio { color: #88c0d0; padding: 0 6px; }
EOF

# rofi colors.rasi
cat > theme-nord/.config/rofi/colors/colors.rasi <<'EOF'
* {
  background:     #2e3440;
  background-alt: #3b4252;
  foreground:     #eceff4;
  selected:       #88c0d0;
  active:         #a3be8c;
  urgent:         #bf616a;
}
EOF

# kitty (keep remote-control block, set palette)
cat > theme-nord/.config/kitty/kitty.conf <<'EOF'
font_family JetBrains Mono
font_size 11
background #2e3440
foreground #eceff4
selection_background #4c566a
selection_foreground #eceff4
cursor #d8dee9
color0  #3b4252
color1  #bf616a
color2  #a3be8c
color3  #ebcb8b
color4  #81a1c1
color5  #b48ead
color6  #88c0d0
color7  #e5e9f0
color8  #4c566a
color9  #bf616a
color10 #a3be8c
color11 #ebcb8b
color12 #81a1c1
color13 #b48ead
color14 #8fbcbb
color15 #eceff4

allow_remote_control socket-only
listen_on unix:/tmp/kitty-{kitty_pid}
EOF

# zsh colors
cat > theme-nord/.local/share/zsh/theme-colors.zsh <<'EOF'
export THEME_NAME="nord"
export THEME_ACCENT="#88c0d0"
export THEME_BG="#2e3440"
export THEME_FG="#eceff4"
EOF

# wallpaper: solid color placeholder (replace later with a real image)
if command -v magick >/dev/null; then
  magick -size 3840x2160 xc:'#2e3440' theme-nord/.local/share/wallpapers/nord.png
else
  : > theme-nord/.local/share/wallpapers/nord.png
fi

# hyprpaper.conf
cat > theme-nord/.config/hypr/hyprpaper.conf <<'EOF'
preload = ~/.local/share/wallpapers/nord.png
wallpaper = , ~/.local/share/wallpapers/nord.png
splash = false
EOF

# Drop files we don't want to override (let them fall back to default)
rm -f theme-nord/.config/hypr/hyprlock.conf
rm -f theme-nord/.config/waybar/config
rm -f theme-nord/.config/nvim/lua/plugins/colorscheme.lua
rm -f theme-nord/.config/gtk-3.0/settings.ini
rm -f theme-nord/.config/gtk-4.0/settings.ini
rm -f theme-nord/.config/rofi/launchers/type-1/shared/colors.rasi
rm -f theme-nord/.config/rofi/applets/shared/colors.rasi
rm -f theme-nord/.config/rofi/powermenu/type-1/shared/colors.rasi
rm -rf theme-nord/usr
rm -f theme-nord/README.md
```

- [ ] **Step 2:** Commit.

```bash
git add theme-nord
git commit -m "theme-nord: initial palette + overrides"
```

### Task 6.3: `theme-dracula/`

Same shape as 6.2 with Dracula palette: `#282a36` bg, `#f8f8f2` fg, `#44475a` selection, `#6272a4`, `#8be9fd`, `#50fa7b`, `#ffb86c`, `#ff79c6`, `#bd93f9`, `#ff5555`, `#f1fa8c`.

- [ ] **Step 1:** Scaffold from template with Dracula palette.

```bash
cd ~/hypr-dots
cp -a theme-template theme-dracula
cat > theme-dracula/meta.toml <<'EOF'
name          = "Dracula"
description   = "purples · neon accents"
accent        = "#bd93f9"
preview       = ".local/share/wallpapers/dracula.png"
colorscheme   = "dracula"
gtk_theme     = "Dracula"
icon_theme    = "Adwaita"
cursor_theme  = "Adwaita"
cursor_size   = 24
EOF

cat > theme-dracula/.config/hypr/hyprland/look_and_feel.conf <<'EOF'
general {
  gaps_in = 4
  gaps_out = 8
  border_size = 2
  col.active_border = rgba(bd93f9ee) rgba(ff79c6ee) 45deg
  col.inactive_border = rgba(44475aaa)
  resize_on_border = false
  allow_tearing = false
  layout = dwindle
}
decoration {
  rounding = 4
  rounding_power = 2
  active_opacity = 0.92
  inactive_opacity = 0.88
  shadow { enabled = true; range = 4; render_power = 3; color = rgba(282a36ee) }
  blur { enabled = true; size = 10; passes = 2; vibrancy = 0.12 }
}
EOF

cat > theme-dracula/.config/waybar/style.css <<'EOF'
* { font-family: FontAwesome, Roboto, Helvetica, Arial, sans-serif; font-size: 13px; }
window#waybar { background-color: rgba(40, 42, 54, 0.75); color: #f8f8f2; padding: 4px; }
#workspaces button { color: #f8f8f2; padding: 0 6px; }
#workspaces button.active { color: #bd93f9; border-bottom: 2px solid #ff79c6; }
#clock, #network, #pulseaudio { color: #8be9fd; padding: 0 6px; }
EOF

cat > theme-dracula/.config/rofi/colors/colors.rasi <<'EOF'
* {
  background:     #282a36;
  background-alt: #44475a;
  foreground:     #f8f8f2;
  selected:       #bd93f9;
  active:         #50fa7b;
  urgent:         #ff5555;
}
EOF

cat > theme-dracula/.config/kitty/kitty.conf <<'EOF'
font_family JetBrains Mono
font_size 11
background #282a36
foreground #f8f8f2
selection_background #44475a
selection_foreground #f8f8f2
cursor #f8f8f2
color0  #21222c
color1  #ff5555
color2  #50fa7b
color3  #f1fa8c
color4  #bd93f9
color5  #ff79c6
color6  #8be9fd
color7  #f8f8f2
color8  #6272a4
color9  #ff6e6e
color10 #69ff94
color11 #ffffa5
color12 #d6acff
color13 #ff92df
color14 #a4ffff
color15 #ffffff

allow_remote_control socket-only
listen_on unix:/tmp/kitty-{kitty_pid}
EOF

cat > theme-dracula/.local/share/zsh/theme-colors.zsh <<'EOF'
export THEME_NAME="dracula"
export THEME_ACCENT="#bd93f9"
export THEME_BG="#282a36"
export THEME_FG="#f8f8f2"
EOF

if command -v magick >/dev/null; then
  magick -size 3840x2160 xc:'#282a36' theme-dracula/.local/share/wallpapers/dracula.png
else
  : > theme-dracula/.local/share/wallpapers/dracula.png
fi

cat > theme-dracula/.config/hypr/hyprpaper.conf <<'EOF'
preload = ~/.local/share/wallpapers/dracula.png
wallpaper = , ~/.local/share/wallpapers/dracula.png
splash = false
EOF

rm -f theme-dracula/.config/hypr/hyprlock.conf
rm -f theme-dracula/.config/waybar/config
rm -f theme-dracula/.config/nvim/lua/plugins/colorscheme.lua
rm -f theme-dracula/.config/gtk-3.0/settings.ini
rm -f theme-dracula/.config/gtk-4.0/settings.ini
rm -f theme-dracula/.config/rofi/launchers/type-1/shared/colors.rasi
rm -f theme-dracula/.config/rofi/applets/shared/colors.rasi
rm -f theme-dracula/.config/rofi/powermenu/type-1/shared/colors.rasi
rm -rf theme-dracula/usr
rm -f theme-dracula/README.md
```

- [ ] **Step 2:** Commit.

```bash
git add theme-dracula
git commit -m "theme-dracula: initial palette + overrides"
```

---

## Phase 7 — Integration test, CI, keybind

### Task 7.1: Integration test (Docker/Arch)

**Files:**
- Create: `tests/integration/Dockerfile`
- Create: `tests/integration/run.sh`

- [ ] **Step 1:** Dockerfile.

```bash
mkdir -p tests/integration
cat > tests/integration/Dockerfile <<'EOF'
FROM archlinux:latest
RUN pacman -Sy --noconfirm bash stow bats git coreutils awk gawk rsync && \
    useradd -m marvin
USER marvin
WORKDIR /home/marvin
EOF
```

- [ ] **Step 2:** run.sh.

```bash
cat > tests/integration/run.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
REPO=$(readlink -f "$HERE/../..")

docker build -t theme-switch-it -f "$HERE/Dockerfile" "$HERE"

docker run --rm -v "$REPO:/home/marvin/hypr-dots:ro" theme-switch-it bash -euc '
  cp -a /home/marvin/hypr-dots /home/marvin/work
  cd /home/marvin/work
  mkdir -p /home/marvin/.local/state/theme-switch
  cd /home/marvin
  stow -d /home/marvin/work hypr-base theme-default
  PATH=/home/marvin/bin:/usr/bin theme-switch nord
  PATH=/home/marvin/bin:/usr/bin theme-switch dracula
  test "$(cat /home/marvin/.local/state/theme-switch/active)" = dracula
  PATH=/home/marvin/bin:/usr/bin theme-switch --rollback
  test "$(cat /home/marvin/.local/state/theme-switch/active)" = nord
  echo "integration: OK"
'
EOF
chmod +x tests/integration/run.sh
```

- [ ] **Step 3:** Run.

Run: `tests/integration/run.sh`
Expected: "integration: OK".

- [ ] **Step 4:** Commit.

```bash
git add tests/integration
git commit -m "tests: Arch-container integration test"
```

### Task 7.2: Manual smoke checklist

**Files:**
- Create: `tests/manual-smoke.md`

- [ ] **Step 1:** Write.

```bash
cat > tests/manual-smoke.md <<'EOF'
# Manual smoke checklist — post-migration

Run these once on the live system after Phase 1 finishes and at least one alternate theme exists.

- [ ] `theme-switch --current` prints `default`
- [ ] `theme-switch nord` returns 0; desktop recolors without logout
- [ ] Running kitty instances change palette
- [ ] Waybar reloads with new style
- [ ] Rofi next launch shows nord-tinted picker
- [ ] Hyprlock (next `$mainMod+L`) uses nord
- [ ] Wallpaper changes to nord.png
- [ ] nvim running instances re-:colorscheme (visible colors change)
- [ ] GTK apps pick up theme (at least one — e.g., Dolphin)
- [ ] `theme-switch --rollback` returns to previous
- [ ] `$mainMod+T` opens rofi picker; confirm prompt applies
- [ ] After reboot, SDDM login screen shows the active theme (only if a bundled SDDM theme exists)
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add tests/manual-smoke.md
git commit -m "tests: manual smoke checklist"
```

### Task 7.3: GitHub Actions CI

**Files:**
- Create: `.github/workflows/test.yml`

- [ ] **Step 1:** Write.

```bash
mkdir -p .github/workflows
cat > .github/workflows/test.yml <<'EOF'
name: test
on:
  push:
  pull_request:
jobs:
  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y bats stow
      - run: bats tests/theme-switch.bats tests/hooks
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tests/integration/run.sh
EOF
```

- [ ] **Step 2:** Commit.

```bash
git add .github/workflows/test.yml
git commit -m "ci: run bats + integration test on push/PR"
```

### Task 7.4: Keybind

**Files:**
- Modify: `hypr-base/.config/hypr/hyprland/keybinds.conf`

- [ ] **Step 1:** Append.

```bash
cat >> hypr-base/.config/hypr/hyprland/keybinds.conf <<'EOF'

# theme-switch
bind = $mainMod, T, exec, ~/bin/theme-switch-rofi
EOF
```

- [ ] **Step 2:** Reload.

Run: `hyprctl reload`
Expected: no error.

- [ ] **Step 3:** Commit.

```bash
git add hypr-base/.config/hypr/hyprland/keybinds.conf
git commit -m "hypr: bind \$mainMod+T to theme-switch-rofi"
```

---

## Phase 8 — Live smoke test

### Task 8.1: Default sanity

- [ ] **Step 1:** `theme-switch --current` prints `default`. If not, run `echo default > ~/.local/state/theme-switch/active`.

- [ ] **Step 2:** `theme-switch default` — should succeed idempotently.

- [ ] **Step 3:** Sanity checks from `tests/manual-smoke.md` items 1-3.

### Task 8.2: Switch to nord

- [ ] **Step 1:** `theme-switch nord`.

- [ ] **Step 2:** Walk through `tests/manual-smoke.md` items 4-9.

### Task 8.3: Switch to dracula, rollback

- [ ] **Step 1:** `theme-switch dracula`. Confirm color shift.

- [ ] **Step 2:** `theme-switch --rollback`. Confirm reverts to nord.

### Task 8.4: Rofi picker

- [ ] **Step 1:** Press `$mainMod+T`. Picker appears.

- [ ] **Step 2:** Pick default. Confirm Yes. Confirm applies.

### Task 8.5: Push

- [ ] **Step 1:** `git push -u origin theme-switcher`.

- [ ] **Step 2:** (Optional) open a PR on GitHub.

- [ ] **Step 3:** Merge to master only after all manual smoke items pass.

---

## Self-review

### Spec coverage

| Spec section | Implemented in |
| ------------ | -------------- |
| Layout (`hypr-base/`, `theme-default/`, overlays, template, install/, state/) | Task 1.1, 6.1, 6.2, 6.3, 0.2 |
| Switch algorithm (stow -D → -R default → --override overlay → hooks) | Task 2.6 |
| CLI surface (`--list`, `--current`, `--dry-run`, `--rollback`, `<name>`) | Tasks 2.2, 2.3, 2.4, 2.5, 2.6, 2.9 |
| 9 reload hooks (10-hyprland ... 95-sddm) | Tasks 3.1 – 3.9 |
| Environment assumptions (kitty remote, nvim server, .zshrc precmd) | Tasks 1.6, 1.7, 1.8 |
| Rofi UI with meta.toml + confirm step + fallback | Tasks 4.1, 4.2 |
| SDDM polkit helper + policy + installer | Tasks 5.1, 5.2, 5.3, 5.4 |
| Fallback via stow --override | Task 2.6 (implementation); Task 6.2/6.3 (nord/dracula only ship overrides) |
| Stow conflict → refuse w/ clear message | Covered by stow default behavior; validated by Task 1.19 dry-run |
| Partial switch failure → trap + recovery | Task 2.6 |
| Hook failure isolation | Task 2.6 + Task 2.8 |
| Missing external tool → skip | Every hook's `command -v` check |
| Same-theme re-apply | Task 2.6 does not early-return on same |
| Unknown theme rejection | Task 2.4 |
| Concurrent switches → flock | Task 2.6 + Task 2.7 |
| SDDM helper missing → non-fatal | Task 3.9 (hook) |
| Hyprland not running → hyprctl skip | Every hyprctl-using hook |
| Wallpaper missing → notify | Covered by `|| true` in hook 15 + manifest sanity pass |
| Nvim without socket → skip | Task 3.5 (nullglob) |
| State corruption → assume default | `ts_current_theme` default-fallback |
| Rollback one level | Task 2.9 |
| Manifest sanity pass | Task 2.10 |
| Logging (`state/log`) | `_ts_log_line` in Task 2.1 |
| bats unit tests | Every Phase 2/3 task's TDD cycle |
| Hook tests | Tasks 3.1 – 3.9 |
| Integration test (Arch container) | Task 7.1 |
| Manual smoke checklist | Task 7.2 |
| CI workflow | Task 7.3 |
| Keybind `$mainMod+T` | Task 7.4 |

All spec requirements mapped. Open items (palette details, exact icon/cursor themes, SDDM theme dirs) are intentionally implementer-choice in Tasks 6.2/6.3/5.1 — palettes chosen; SDDM theme dirs left empty.

### Placeholder scan

- No "TBD"/"TODO" in plan body.
- No "add appropriate error handling" — every hook has specific error handling (`|| true`, `command -v`, `exit 0`).
- No "similar to Task N" — code blocks repeat where needed (e.g., Nord and Dracula both show full files).
- No undefined types/functions — `ts_list_themes`, `ts_current_theme`, `ts_meta_value`, `_ts_err`, `_ts_info`, `_ts_log_line` all defined in Task 2.1 and used consistently afterward.

### Type/identifier consistency

- `theme-switch-lib.sh` env vars: `THEME_SWITCH_ROOT`, `THEME_SWITCH_STATE` — used consistently.
- State files: `state/active`, `state/previous`, `state/lock`, `state/log`, `state/zsh-marker` — consistent.
- meta.toml keys: `name`, `description`, `accent`, `preview`, `colorscheme`, `gtk_theme`, `icon_theme`, `cursor_theme`, `cursor_size` — consistent across hooks 50/60/70, rofi UI, and template/nord/dracula meta files.
- Hook filename format: `NN-<tool>.sh` — consistent.
- Exit codes: `0` = ok (incl. "tool missing, skipped"), `1` = user error (unknown theme, nothing to rollback), `2` = usage error — consistent.

### Scope check

One implementation plan, eight phases, ~55 tasks. Each task is self-contained and sequentially buildable. The integration test at Task 7.1 validates the end-to-end filesystem behavior; manual smoke in Task 8 validates the live-system behavior. Worktree is the current `theme-switcher` branch in `~/hypr-dots/`.

No remaining placeholders found. Plan is ready to execute.
