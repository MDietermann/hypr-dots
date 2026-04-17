# theme-sakura Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new kawaii-styled dark theme `theme-sakura` with deep-plum surfaces and coral-pink + gold accents, selectable via the existing `theme-switch` mechanism.

**Architecture:** Drop-in theme directory following the established `theme-<name>/` layout. Per-surface color files mirror the `theme-default/` structure. Starship integration extends the existing theme-hook case statement. GTK uses Adwaita-dark plus a small accent-override `gtk.css` (no new GTK theme package).

**Tech Stack:** Hyprland, hyprlock, hyprpaper, kitty, waybar, rofi, neovim (LazyVim + rose-pine), zellij, starship, zsh, GTK 3/4, bats.

**Design doc:** `docs/superpowers/specs/2026-04-17-theme-sakura-design.md`

**Palette constants referenced throughout:**

```
bg        = #2B1E2B   plum base
bg-alt    = #3B2A3D   plum lifted
fg        = #F5E6D3   cream
fg-dim    = #C9B8A8   muted cream
accent    = #F4A3B0   coral pink (mane)
accent2   = #E8C974   gold (horn)
ok        = #A8D8B9   mint
warn      = #E8C974
err       = #E8738A   kawaii red
info      = #A8C5E8   pastel blue
muted     = #5A4458   plum muted
```

---

## Task 1: Scaffold theme-sakura directory, meta.toml, and wallpaper

**Files:**
- Create: `theme-sakura/meta.toml`
- Create: `theme-sakura/.local/share/wallpapers/sakura.png` (binary copy)

- [ ] **Step 1: Create directory tree**

```bash
cd /home/marvin/hypr-dots
mkdir -p theme-sakura/.local/share/wallpapers
mkdir -p theme-sakura/.local/share/zsh
mkdir -p theme-sakura/.config/hypr/hyprland
mkdir -p theme-sakura/.config/kitty
mkdir -p theme-sakura/.config/waybar
mkdir -p theme-sakura/.config/rofi/colors
mkdir -p theme-sakura/.config/rofi/applets/shared
mkdir -p theme-sakura/.config/rofi/launchers/type-1/shared
mkdir -p theme-sakura/.config/rofi/powermenu/type-1/shared
mkdir -p theme-sakura/.config/nvim/lua/plugins
mkdir -p theme-sakura/.config/zellij/themes
mkdir -p theme-sakura/.config/gtk-3.0
mkdir -p theme-sakura/.config/gtk-4.0
```

- [ ] **Step 2: Copy wallpaper into the theme**

```bash
cp ~/Downloads/kawaii-unicorn-cute-3840x2160-10121.png \
   /home/marvin/hypr-dots/theme-sakura/.local/share/wallpapers/sakura.png
```

Verify: `ls -la /home/marvin/hypr-dots/theme-sakura/.local/share/wallpapers/sakura.png` — file size ≥ 100 KB.

- [ ] **Step 3: Write meta.toml**

Write to `theme-sakura/meta.toml`:

```toml
name         = "Sakura"
description  = "kawaii · coral pink & gold"
accent       = "#F4A3B0"
preview      = ".local/share/wallpapers/sakura.png"
colorscheme  = "rose-pine"
gtk_theme    = "Adwaita-dark"
icon_theme   = "Adwaita"
cursor_theme = "Adwaita"
cursor_size  = 24
```

- [ ] **Step 4: Verify TOML parses**

Run: `python3 -c "import tomllib; tomllib.loads(open('/home/marvin/hypr-dots/theme-sakura/meta.toml').read())"`
Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /home/marvin/hypr-dots
git add theme-sakura/meta.toml theme-sakura/.local/share/wallpapers/sakura.png
git commit -m "theme-sakura: add meta.toml and wallpaper"
```

---

## Task 2: Hyprland look_and_feel.conf

**Files:**
- Create: `theme-sakura/.config/hypr/hyprland/look_and_feel.conf`

- [ ] **Step 1: Write the file**

Copy `theme-default/.config/hypr/hyprland/look_and_feel.conf` verbatim, then change only these two lines in the `general {}` block:

```
col.active_border   = rgba(f4a3b0ee) rgba(e8c974ee) 45deg
col.inactive_border = rgba(5a4458aa)
```

Concrete approach: read `theme-default/.config/hypr/hyprland/look_and_feel.conf`, duplicate to the sakura path, then `sed` or Edit the two `col.*_border` lines.

- [ ] **Step 2: Verify the override lines are correct**

```bash
grep -E 'col\.(active|inactive)_border' \
  /home/marvin/hypr-dots/theme-sakura/.config/hypr/hyprland/look_and_feel.conf
```

Expected:
```
col.active_border   = rgba(f4a3b0ee) rgba(e8c974ee) 45deg
col.inactive_border = rgba(5a4458aa)
```

- [ ] **Step 3: Verify no other drift from default**

```bash
diff -u \
  /home/marvin/hypr-dots/theme-default/.config/hypr/hyprland/look_and_feel.conf \
  /home/marvin/hypr-dots/theme-sakura/.config/hypr/hyprland/look_and_feel.conf
```

Expected: only two changed lines (`col.active_border`, `col.inactive_border`).

- [ ] **Step 4: Commit**

```bash
git add theme-sakura/.config/hypr/hyprland/look_and_feel.conf
git commit -m "theme-sakura: hyprland border gradient (coral → gold)"
```

---

## Task 3: hyprlock.conf and hyprpaper.conf

**Files:**
- Create: `theme-sakura/.config/hypr/hyprlock.conf`
- Create: `theme-sakura/.config/hypr/hyprpaper.conf`

- [ ] **Step 1: Write hyprlock.conf**

```
background {
    monitor =
    color = rgba(2b1e2bee) rgba(3b2a3dee) 120deg
    blur_passes = 2
}

input-field {
    monitor = DP-2
    size = 20%, 5%
    outline_thickness = 3
    inner_color = rgba(0, 0, 0, 0.0)

    outer_color = rgba(f4a3b0ee) rgba(e8c974ee) 45deg
    check_color = rgba(a8d8b9ee) rgba(e8c974ee) 120deg
    fail_color  = rgba(e8738aee) rgba(f4a3b0ee) 40deg

    font_color = rgb(245, 230, 211)
    fade_on_empty = false
    rounding = 15

    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor = DP-2
    text = Hi there, $USER
    color = rgba(f4a3b0ee)
    font_size = 25
    font_family = Noto Sans

    position = 0, 80
    halign = center
    valign = center
}

label {
    monitor = HDMI-A-2
    text = cmd[update:60] echo $TIME
    color = rgba(f4a3b0ee)
    font_size = 50
    font_family = Noto Sans
    position = 0, 0
    halign = center
    valign = center
}
```

Note: fixed typo from default (`font_family = Nono Sans` → `Noto Sans`).

- [ ] **Step 2: Write hyprpaper.conf**

```
splash = false

wallpaper {
    monitor =
    path = ~/.local/share/wallpapers/sakura.png
}
```

- [ ] **Step 3: Verify the hyprpaper block syntax matches the v0.8.3 migration**

```bash
grep -c "^wallpaper {" /home/marvin/hypr-dots/theme-sakura/.config/hypr/hyprpaper.conf
```

Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add theme-sakura/.config/hypr/hyprlock.conf theme-sakura/.config/hypr/hyprpaper.conf
git commit -m "theme-sakura: hyprlock gradients and hyprpaper path"
```

---

## Task 4: Kitty color block

**Context:** `theme-default/.config/kitty/kitty.conf` is the stock kitty config — most color directives are commented out (only `cursor #32a852` is uncommented). Sakura needs an explicit uncommented color block.

**Files:**
- Create: `theme-sakura/.config/kitty/kitty.conf`

- [ ] **Step 1: Copy the default kitty.conf as the starting file**

```bash
cp /home/marvin/hypr-dots/theme-default/.config/kitty/kitty.conf \
   /home/marvin/hypr-dots/theme-sakura/.config/kitty/kitty.conf
```

- [ ] **Step 2: Replace the `cursor` line**

Find the line `cursor #32a852` (around line 270) and replace with:

```
cursor #F4A3B0
```

- [ ] **Step 3: Append the sakura color block at end of file**

Append this block (ensures all color directives are explicit, regardless of which defaults are commented):

```
# --- theme-sakura palette ---
foreground            #F5E6D3
background            #2B1E2B
selection_foreground  #2B1E2B
selection_background  #F4A3B0

cursor                #F4A3B0
cursor_text_color     #2B1E2B

url_color             #A8C5E8

# black
color0  #3B2A3D
color8  #5A4458
# red
color1  #E8738A
color9  #F48FA3
# green
color2  #A8D8B9
color10 #BEE5CC
# yellow
color3  #E8C974
color11 #F0D98A
# blue
color4  #A8C5E8
color12 #BDD4F0
# magenta
color5  #F4A3B0
color13 #F9BFC9
# cyan
color6  #B5D4D4
color14 #CCE3E3
# white
color7  #F5E6D3
color15 #FFF2E0

active_tab_foreground    #2B1E2B
active_tab_background    #F4A3B0
inactive_tab_foreground  #C9B8A8
inactive_tab_background  #3B2A3D
```

- [ ] **Step 4: Verify the palette was appended**

```bash
grep -c "^color0 " /home/marvin/hypr-dots/theme-sakura/.config/kitty/kitty.conf
grep "^background " /home/marvin/hypr-dots/theme-sakura/.config/kitty/kitty.conf
```

Expected:
- `color0 ` count: `1`
- `background` line: `background            #2B1E2B`

- [ ] **Step 5: Commit**

```bash
git add theme-sakura/.config/kitty/kitty.conf
git commit -m "theme-sakura: kitty palette (plum bg, coral + gold accents)"
```

---

## Task 5: Waybar style.css

**Files:**
- Create: `theme-sakura/.config/waybar/style.css`

- [ ] **Step 1: Write the file**

Mirror the structure of `theme-default/.config/waybar/style.css` but with the sakura palette:

```css
* {
    font-family: FontAwesome, "JetBrains Mono", Roboto, Helvetica, Arial, sans-serif;
    font-size: 13px;
}

window#waybar {
    background-color: rgba(43, 30, 43, 0.0);
    border-bottom: 3px solid rgba(244, 163, 176, 0.0);
    color: #F5E6D3;
    padding: 4px;
    transition-property: background-color;
    transition-duration: .5s;
}

window#waybar.hidden {
    opacity: 0.2;
}

window#waybar.termite {
    background-color: #3B2A3D;
}

window#waybar.chromium {
    background-color: #2B1E2B;
    border: none;
}

button {
    box-shadow: inset 0 -3px transparent;
    transition: all ease-out 0.3s;
}

button:hover {
    background: inherit;
    box-shadow: inset 0 -3px #F4A3B0;
}

#pulseaudio:hover {
    background-color: #E8C974;
}

#workspaces button {
    padding: 0 5px;
    background-color: transparent;
    border-radius: 8px;
    color: rgba(245, 230, 211, 0.6);
    margin: 4px;
}

#workspaces button:hover {
    background: rgba(244, 163, 176, 0.2);
}

#workspaces button.focused, #workspaces button.active {
    background-color: rgba(244, 163, 176, 0.2);
    box-shadow: inset 0 -3px #F4A3B0;
}

#workspaces button.urgent {
    background-color: #E8738A;
}

#mode {
    background-color: #3B2A3D;
    box-shadow: inset 0 -3px #F4A3B0;
}

#clock,
#battery,
#cpu,
#memory,
#disk,
#temperature,
#backlight,
#network,
#pulseaudio,
#wireplumber,
#custom-media,
#tray,
#mode,
#idle_inhibitor,
#scratchpad,
#power-profiles-daemon,
#mpd {
    color: rgba(245, 230, 211, 0.85);
    background-color: transparent;
    box-shadow: inset 0 -3px rgba(244, 163, 176, 0.3);
    border-radius: 8px;
    margin: 4px;
    padding: 0 5px;
}

#window,
#workspaces {
    margin: 0 4px;
}

.modules-left > widget:first-child > #workspaces {
    margin-left: 0;
}

.modules-right > widget:last-child > #workspaces {
    margin-right: 0;
}

label:focus {
    background-color: #2B1E2B;
}

#custom-media {
    background-color: #A8D8B9;
    color: #2B1E2B;
    min-width: 100px;
}

#custom-media.custom-spotify {
    background-color: #A8D8B9;
}

#custom-media.custom-vlc {
    background-color: #E8C974;
}

#tray {
    background-color: #3B2A3D;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: #E8738A;
}

#idle_inhibitor {
    background-color: #3B2A3D;
}

#idle_inhibitor.activated {
    background-color: #F5E6D3;
    color: #3B2A3D;
}
```

- [ ] **Step 2: Commit**

```bash
git add theme-sakura/.config/waybar/style.css
git commit -m "theme-sakura: waybar style (cream text, coral accents)"
```

---

## Task 6: Rofi color files

**Files:**
- Create: `theme-sakura/.config/rofi/colors/colors.rasi`
- Create: `theme-sakura/.config/rofi/applets/shared/colors.rasi`
- Create: `theme-sakura/.config/rofi/launchers/type-1/shared/colors.rasi`
- Create: `theme-sakura/.config/rofi/powermenu/type-1/shared/colors.rasi`

- [ ] **Step 1: Write all four files with identical content**

```rasi
/**
 *
 * theme-sakura palette
 *
 **/

* {
    background:     #2B1E2BFF;
    background-alt: #3B2A3DFF;
    foreground:     #F5E6D3FF;
    selected:       #F4A3B0FF;
    active:         #E8C974FF;
    urgent:         #E8738AFF;
}
```

- [ ] **Step 2: Verify all four exist**

```bash
find /home/marvin/hypr-dots/theme-sakura/.config/rofi -name 'colors.rasi' | sort
```

Expected (4 lines):
```
/home/marvin/hypr-dots/theme-sakura/.config/rofi/applets/shared/colors.rasi
/home/marvin/hypr-dots/theme-sakura/.config/rofi/colors/colors.rasi
/home/marvin/hypr-dots/theme-sakura/.config/rofi/launchers/type-1/shared/colors.rasi
/home/marvin/hypr-dots/theme-sakura/.config/rofi/powermenu/type-1/shared/colors.rasi
```

- [ ] **Step 3: Commit**

```bash
git add theme-sakura/.config/rofi/
git commit -m "theme-sakura: rofi palettes"
```

---

## Task 7: Zellij theme

**Files:**
- Create: `theme-sakura/.config/zellij/themes/current.kdl`

- [ ] **Step 1: Write the file**

```kdl
themes {
    current {
        fg      "#F5E6D3"
        bg      "#2B1E2B"
        black   "#3B2A3D"
        red     "#E8738A"
        green   "#A8D8B9"
        yellow  "#E8C974"
        blue    "#A8C5E8"
        magenta "#F4A3B0"
        cyan    "#B5D4D4"
        white   "#F5E6D3"
        orange  "#F4A3B0"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add theme-sakura/.config/zellij/themes/current.kdl
git commit -m "theme-sakura: zellij palette"
```

---

## Task 8: ZSH theme-colors palette

**Files:**
- Create: `theme-sakura/.local/share/zsh/theme-colors.zsh`

- [ ] **Step 1: Write the file**

```zsh
# theme-sakura palette (consumed by prompt/plugins as they see fit)
export THEME_NAME="sakura"
export THEME_ACCENT="#F4A3B0"
export THEME_BG="#2B1E2B"
export THEME_FG="#F5E6D3"
```

- [ ] **Step 2: Verify the shell can source it**

```bash
bash -n /home/marvin/hypr-dots/theme-sakura/.local/share/zsh/theme-colors.zsh
```

Expected: exit 0, no output.

- [ ] **Step 3: Commit**

```bash
git add theme-sakura/.local/share/zsh/theme-colors.zsh
git commit -m "theme-sakura: zsh palette exports"
```

---

## Task 9: GTK settings + accent CSS override

**Files:**
- Create: `theme-sakura/.config/gtk-3.0/settings.ini`
- Create: `theme-sakura/.config/gtk-3.0/gtk.css`
- Create: `theme-sakura/.config/gtk-4.0/settings.ini`
- Create: `theme-sakura/.config/gtk-4.0/gtk.css`

- [ ] **Step 1: Write both settings.ini files (identical content)**

```
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
```

- [ ] **Step 2: Write both gtk.css files (identical content)**

```css
/* theme-sakura: coral accent override on top of Adwaita-dark */
@define-color accent_color #F4A3B0;
@define-color accent_bg_color #F4A3B0;
@define-color accent_fg_color #2B1E2B;
```

- [ ] **Step 3: Commit**

```bash
git add theme-sakura/.config/gtk-3.0 theme-sakura/.config/gtk-4.0
git commit -m "theme-sakura: GTK settings + coral accent override"
```

---

## Task 10: Neovim colorscheme (rose-pine)

**Files:**
- Create: `theme-sakura/.config/nvim/lua/plugins/colorscheme.lua`

- [ ] **Step 1: Write the file**

```lua
return {
  -- rose-pine for theme-sakura
  { "rose-pine/neovim", name = "rose-pine" },

  -- Configure LazyVim to use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}
```

- [ ] **Step 2: Verify Lua parses**

```bash
lua -e 'dofile("/home/marvin/hypr-dots/theme-sakura/.config/nvim/lua/plugins/colorscheme.lua")'
```

Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add theme-sakura/.config/nvim/lua/plugins/colorscheme.lua
git commit -m "theme-sakura: nvim rose-pine colorscheme"
```

---

## Task 11: Starship hook — add sakura case (TDD)

**Files:**
- Create: `tests/hooks/25-starship.bats`
- Modify: `hypr-base/bin/theme-hooks.d/25-starship.sh`

- [ ] **Step 1: Write the failing bats test**

Create `tests/hooks/25-starship.bats`:

```bash
#!/usr/bin/env bats
load '../helpers'

setup() {
  setup_fake_dotfiles
  cat > "$HOME/.config/starship.toml" <<'SEOF'
palette = "dracula"

[palettes.dracula]
bright-red = "#ff5555"
SEOF
}
teardown() { teardown_fake_dotfiles; }

@test "25-starship: sakura theme rewrites palette to 'sakura'" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/25-starship.sh" sakura
  [ "$status" -eq 0 ]
  grep -q '^palette = "sakura"$' "$HOME/.config/starship.toml"
}

@test "25-starship: dracula theme still maps to dracula palette" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/25-starship.sh" dracula
  [ "$status" -eq 0 ]
  grep -q '^palette = "dracula"$' "$HOME/.config/starship.toml"
}

@test "25-starship: unknown theme leaves palette untouched" {
  run bash "$REPO_ROOT/hypr-base/bin/theme-hooks.d/25-starship.sh" banana
  [ "$status" -eq 0 ]
  grep -q '^palette = "dracula"$' "$HOME/.config/starship.toml"
}
```

Verify `tests/helpers.bash` (loaded as `../helpers`) defines `setup_fake_dotfiles`, `teardown_fake_dotfiles`, `TMP_ROOT`, and `REPO_ROOT`. If the helper name differs, adjust the `load` line to match the existing pattern used by `tests/hooks/30-waybar.bats` (`load '../helpers'`).

- [ ] **Step 2: Run the new test and confirm sakura case fails**

```bash
cd /home/marvin/hypr-dots
bats tests/hooks/25-starship.bats
```

Expected: "25-starship: sakura theme rewrites palette to 'sakura'" FAILS (palette is unchanged because hook has no sakura case). Other two tests pass.

- [ ] **Step 3: Add the sakura case to the hook**

Edit `hypr-base/bin/theme-hooks.d/25-starship.sh`. In the case statement, add a `sakura` arm before the wildcard:

```sh
case "$theme" in
  dracula)  palette="dracula" ;;
  nord)     palette="nord" ;;
  sakura)   palette="sakura" ;;
  default|tokyonight) palette="tokyonight" ;;
  *)
    echo "25-starship: no palette mapping for '$theme', leaving config untouched" >&2
    exit 0
    ;;
esac
```

- [ ] **Step 4: Re-run the test; confirm all three pass**

```bash
bats tests/hooks/25-starship.bats
```

Expected: 3/3 pass.

- [ ] **Step 5: Run full bats suite to confirm no regressions**

```bash
bats tests/
```

Expected: Same pass/fail ratio as before (the known 20-kitty.bats pre-existing failures per project memory are OK; everything else should pass, including our new 25-starship.bats).

- [ ] **Step 6: Commit**

```bash
git add tests/hooks/25-starship.bats hypr-base/bin/theme-hooks.d/25-starship.sh
git commit -m "25-starship: add sakura palette mapping + bats coverage"
```

---

## Task 12: Starship palette block

**Files:**
- Modify: `~/.config/starship.toml`

- [ ] **Step 1: Append sakura palette block**

Append at the end of `~/.config/starship.toml`:

```toml

[palettes.sakura]
bright-yellow = "#E8C974"
bright-green  = "#A8D8B9"
bright-red    = "#E8738A"
bright-blue   = "#A8C5E8"
bright-purple = "#F4A3B0"
bright-aqua   = "#B5D4D4"
bright-orange = "#F4A3B0"
```

These seven keys are the exact set referenced by the existing prompt modules (username, hostname, directory, git_branch, git_status, cmd_duration, time, character, jobs, language modules, docker_context). The key set matches the shape of the existing `[palettes.dracula|nord|tokyonight]` blocks.

- [ ] **Step 2: Verify starship parses the config**

```bash
starship config
```

Expected: exit 0, no parse errors printed to stderr.

- [ ] **Step 3: Manually swap to sakura palette and render a prompt**

```bash
sed -i 's|^palette = ".*"|palette = "sakura"|' ~/.config/starship.toml
starship prompt 2>&1 | head -5
```

Expected: a rendered prompt with coral/pink ANSI escapes, no errors. Then:

```bash
sed -i 's|^palette = ".*"|palette = "dracula"|' ~/.config/starship.toml
```

(Reset palette; the theme hook will set the correct value at theme-switch time.)

- [ ] **Step 4: No commit** (the file lives outside the repo). Note in the verification task that this change exists on the user's home directory.

---

## Task 13: End-to-end verification

**Files:** none to write. Manual verification.

- [ ] **Step 1: Run the full test suite one more time**

```bash
cd /home/marvin/hypr-dots
bats tests/
```

Expected: same pass ratio as before the plan started (22/24 with the two pre-existing 20-kitty failures). The new 25-starship suite contributes 3 additional passes.

- [ ] **Step 2: Switch to sakura and observe**

```bash
theme-switch sakura
```

Expected log output (from hooks):
- `25-starship: palette → sakura`
- `30-waybar: SIGUSR2 sent` (or equivalent)
- no errors from any other hook

- [ ] **Step 3: Eyeball each surface**

- [ ] Wallpaper: the kawaii unicorn+pig image on all monitors.
- [ ] Hyprland: active-window border gradient coral → gold.
- [ ] Kitty: plum bg, cream text, coral cursor. Open a new terminal; run `ls --color=auto` and confirm pastel ANSI.
- [ ] Waybar: transparent bar, cream text, coral underline on hover/focus.
- [ ] Rofi: launcher shows plum bg, cream text, coral selected.
- [ ] Starship prompt: coral `❯`, gold dir, pink username etc.
- [ ] Neovim: on next launch, LazyVim installs rose-pine and applies it.
- [ ] Hyprlock: lock screen shows plum gradient bg, coral outline on input.

- [ ] **Step 4: Switch back to a previous theme to confirm no drift**

```bash
theme-switch default
```

Expected: theme cleanly reverts to default colors on all surfaces.

- [ ] **Step 5: Switch to sakura again**

```bash
theme-switch sakura
```

Expected: sakura cleanly re-applies.

- [ ] **Step 6: Final commit** (only if any fixes were needed during verification; otherwise skip)

```bash
git status
# if clean, no commit needed
# if fixes were made:
git add -u
git commit -m "theme-sakura: verification fixes"
```
