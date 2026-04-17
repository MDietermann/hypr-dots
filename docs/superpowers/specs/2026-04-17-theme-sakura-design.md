# theme-sakura — design

A kawaii-styled dark theme for hypr-dots, derived from the unicorn-pool-float
reference image. Deep plum surfaces with coral-pink and gold accents, cream
text.

## Goals

- New drop-in theme `theme-sakura/` selectable via the existing theme-switch
  mechanism.
- Max surface coverage matching the project's "full theme" scope: kitty,
  waybar, rofi, hyprland borders, hyprlock, nvim, zellij, zsh palette, gtk
  accent, starship prompt palette, wallpaper.
- Kawaii aesthetic (pastel coral + gold + cream) while remaining a usable dark
  theme for long-running terminal and editor sessions.

## Non-goals

- Installing a pink GTK theme package. GTK is handled via an accent-only
  `gtk.css` override on top of Adwaita-dark.
- New fonts, icon theme, or cursor theme.
- Hyprland layout/animation changes — strictly color.
- Multi-monitor wallpaper variants — single image on all outputs.

## Palette

Derived by inverting the light-pink reference into a dark kawaii surface while
keeping the mane-coral, horn-gold, and cream-pig accent colors.

### Surfaces

| Role            | Hex       | Notes                              |
|-----------------|-----------|------------------------------------|
| `bg`            | `#2B1E2B` | deep plum                          |
| `bg-alt`        | `#3B2A3D` | lifted plum (panels, selections)   |
| `fg`            | `#F5E6D3` | cream (from pig body)              |
| `fg-dim`        | `#C9B8A8` | muted cream                        |
| `accent`        | `#F4A3B0` | coral pink (from unicorn mane)     |
| `accent-alt`    | `#E8C974` | gold (from unicorn horn)           |
| `border-active` | gradient `#F4A3B0 → #E8C974` @ 45° | mane → horn |
| `border-inactive` | `#5A4458` | muted plum, alpha 0.67 |

### ANSI 16

| Slot    | Normal    | Bright    |
|---------|-----------|-----------|
| black   | `#3B2A3D` | `#5A4458` |
| red     | `#E8738A` | `#F48FA3` |
| green   | `#A8D8B9` | `#BEE5CC` |
| yellow  | `#E8C974` | `#F0D98A` |
| blue    | `#A8C5E8` | `#BDD4F0` |
| magenta | `#F4A3B0` | `#F9BFC9` |
| cyan    | `#B5D4D4` | `#CCE3E3` |
| white   | `#F5E6D3` | `#FFF2E0` |

## File layout

```
theme-sakura/
  meta.toml
  .local/share/
    wallpapers/sakura.png                 # copied from ~/Downloads/kawaii-unicorn-cute-3840x2160-10121.png
    zsh/theme-colors.zsh
  .config/
    hypr/
      hyprland/look_and_feel.conf
      hyprlock.conf
      hyprpaper.conf
    kitty/kitty.conf
    waybar/style.css
    rofi/
      colors/colors.rasi
      applets/shared/colors.rasi
      launchers/type-1/shared/colors.rasi
      powermenu/type-1/shared/colors.rasi
    nvim/lua/plugins/colorscheme.lua
    zellij/themes/current.kdl
    gtk-3.0/
      settings.ini
      gtk.css
    gtk-4.0/
      settings.ini
      gtk.css
```

### meta.toml

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

## Per-surface specifications

### Hyprland — `.config/hypr/hyprland/look_and_feel.conf`

Copy of `theme-default/.../look_and_feel.conf` with only color values changed:

```
col.active_border   = rgba(f4a3b0ee) rgba(e8c974ee) 45deg
col.inactive_border = rgba(5a4458aa)
```

Everything else (gaps, rounding, animations, dwindle/master config, workspace
rules, misc) is identical to default. No structural changes.

### Hyprlock — `.config/hypr/hyprlock.conf`

Same monitor bindings as default (DP-2, HDMI-A-2). Color changes only:

- `background.color`: gradient `rgba(2b1e2bee) → rgba(3b2a3dee) 120deg`
- `input-field.outer_color`: gradient `rgba(f4a3b0ee) → rgba(e8c974ee) 45deg`
- `input-field.check_color`: gradient `rgba(a8d8b9ee) → rgba(e8c974ee) 120deg`
- `input-field.fail_color`: gradient `rgba(e8738aee) → rgba(f4a3b0ee) 40deg`
- `input-field.font_color`: `rgb(245, 230, 211)` (cream)
- Both `label.color`: `rgba(f4a3b0ee)` (coral)

### Hyprpaper — `.config/hypr/hyprpaper.conf`

Block syntax (per migration at `4488728`):

```
splash = false

wallpaper {
    monitor =
    path = ~/.local/share/wallpapers/sakura.png
}
```

### Kitty — `.config/kitty/kitty.conf`

Start from `theme-default/.../kitty.conf` (the large config); replace only:

- `background`, `foreground`, `cursor`, `cursor_text_color`
- `selection_background`, `selection_foreground`
- `color0..color15`
- any URL / mark colors if present — map to accent palette

No font, keybind, or behavior changes. Aim: a pure color delta.

### Waybar — `.config/waybar/style.css`

Start from `theme-default/.config/waybar/style.css`. Recolor-only:

- `window#waybar.color` → cream `#F5E6D3`
- `#workspaces button.color` → cream alpha 0.5
- `#workspaces button:hover` `box-shadow` → coral
- `#workspaces button.focused/.active` `box-shadow` → coral
- `#clock, #battery, …` group: `color` cream alpha 0.5, `box-shadow` coral alpha 0.2
- `#custom-media` green → mint `#A8D8B9` with plum text
- `#tray` → plum `#3B2A3D`
- `#tray > .needs-attention` → kawaii-red `#E8738A`
- `#idle_inhibitor` → plum; `.activated` → cream on plum

Preserve the layout, margins, padding, radii, transitions.

### Rofi

Four files, all using the same 6-field palette the existing themes use:

```rasi
* {
    background:     #2B1E2BFF;
    background-alt: #3B2A3DFF;
    foreground:     #F5E6D3FF;
    selected:       #F4A3B0FF;
    active:         #E8C974FF;
    urgent:         #E8738AFF;
}
```

Write this to:

- `.config/rofi/colors/colors.rasi`
- `.config/rofi/applets/shared/colors.rasi`
- `.config/rofi/launchers/type-1/shared/colors.rasi`
- `.config/rofi/powermenu/type-1/shared/colors.rasi`

### Neovim — `.config/nvim/lua/plugins/colorscheme.lua`

```lua
return {
  { "rose-pine/neovim", name = "rose-pine" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}
```

### Zellij — `.config/zellij/themes/current.kdl`

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

### GTK — `.config/gtk-3.0/settings.ini`, `.config/gtk-4.0/settings.ini`

Identical to default:

```
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
```

Plus a new `gtk.css` in each directory with coral accent overrides:

```css
@define-color accent_color #F4A3B0;
@define-color accent_bg_color #F4A3B0;
@define-color accent_fg_color #2B1E2B;
```

### ZSH palette — `.local/share/zsh/theme-colors.zsh`

```
export THEME_NAME="sakura"
export THEME_ACCENT="#F4A3B0"
export THEME_BG="#2B1E2B"
export THEME_FG="#F5E6D3"
```

### Starship — modifications outside theme-sakura/

Starship config is user-level (`~/.config/starship.toml`), not per-theme. Two
external edits:

1. `hypr-base/bin/theme-hooks.d/25-starship.sh` — add a case arm:

   ```sh
   sakura) palette="sakura" ;;
   ```

2. `~/.config/starship.toml` — add a `[palettes.sakura]` block mirroring the
   shape of the existing `[palettes.dracula|nord|tokyonight]` blocks. The
   palette keys referenced by starship modules (read from the existing
   starship.toml before editing) must all be present, mapped to the sakura
   palette:

   - overall bg/fg surface: plum `#2B1E2B` / cream `#F5E6D3`
   - primary accent (dir, prompt char): coral `#F4A3B0`
   - secondary accent (git, lang): gold `#E8C974`
   - ok/success: mint `#A8D8B9`
   - warn: gold `#E8C974`
   - error: kawaii-red `#E8738A`
   - muted: `#C9B8A8`

   The implementation plan must first read the existing palette blocks to
   enumerate the exact keys before writing the sakura block, to avoid
   referencing undefined colors.

## Wallpaper

Copy `~/Downloads/kawaii-unicorn-cute-3840x2160-10121.png` to
`theme-sakura/.local/share/wallpapers/sakura.png`. Set as the theme wallpaper
via `hyprpaper.conf`. The `meta.toml` preview points at the same file.

## Testing

- `bats tests/` — run the existing suite. Expected: 22/24 pass, same as
  pre-change state (20-kitty.bats has two pre-existing failures per memory
  ID 934).
- No new bats tests required unless `25-starship.sh` has existing test
  coverage; if it does, add a sakura case assertion.
- Manual: `theme-switch sakura`; eyeball kitty, waybar, rofi launcher,
  hyprlock, and the starship prompt.

## Risks / edge cases

- **rose-pine plugin.** LazyVim needs the plugin entry; first nvim launch
  after switch will install it via lazy.nvim. Noted — no action needed
  beyond writing the `colorscheme.lua`.
- **Starship palette key drift.** `starship.toml` might reference palette
  keys that the three existing palette blocks define but a naive sakura
  block forgets. Mitigation: enumerate keys from an existing palette block
  first, then replicate every key in the new sakura block.
- **Kitty config is large** (~2000+ lines). Use targeted edits to the color
  assignments only; do not rewrite the file.
- **Waybar style.css** (or kitty) — don't drop comments/structure; color
  swaps only, to keep future merges with upstream defaults clean.
