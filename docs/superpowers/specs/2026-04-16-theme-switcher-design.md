# Theme Switcher — Design

Date: 2026-04-16
Status: Approved (brainstorming phase complete; ready for implementation plan)
Scope: `~/hypr-dots/` dotfiles repo

## Summary

A rofi-triggered theme switcher for the Hyprland dotfiles. Named themes bundle a wallpaper and a complete set of matching configs for every visual component (hyprland, kitty, waybar config + style, rofi, hyprlock, SDDM, hyprpaper, nvim colorscheme, GTK, cursor, icons, zsh prompt colors). Themes are GNU-stow packages; a fallback theme fills in any file a chosen theme omits. The switcher attempts to hot-reload every running application.

Ship initially: `theme-default` (current look captured), `theme-nord`, `theme-dracula`, and `theme-template` (skeleton for creating new themes).

## Goals

- One-command / rofi-click switch between named themes.
- Themes are stow packages — consistent with the existing dotfiles workflow, git-tracked.
- A theme can omit files; missing files fall back to `theme-default`.
- Hot-reload every tool that supports it; tools that don't pick up on next launch.
- SDDM theme switches without typing a password (polkit-authorized narrow helper).
- Adding a new theme = `cp -r theme-template theme-<name>`, edit files, done.

## Non-goals

- Dynamic palette extraction from wallpapers (pywal/matugen) — explicitly deferred.
- Cross-distro portability — targets this Arch + Hyprland setup.
- Graphical theme editor — themes are edited as files in `$EDITOR`.

## Architecture

### Layout

```
~/hypr-dots/
  hypr-base/                                  stow pkg — shared, always stowed
    .config/hypr/hyprland.conf
    .config/hypr/hypridle.conf
    .config/hypr/hyprland/{keybinds,programs,input,autostart,window_and_workspaces}.conf
    .config/hypr/Viking_Rune.png              asset, stays with base
    .config/rofi/applets/                     shared applet scripts
    .config/rofi/launchers/                   shared launcher scripts
    .config/rofi/powermenu/
    .config/rofi/images/
    .config/nvim/                             everything except colorscheme plugin
    .config/theme-switch/manifest.txt         list of every per-theme file path
    .zshrc                                    sources theme-colors.zsh
    bin/theme-switch                          CLI
    bin/theme-switch-rofi                     rofi front-end
    bin/theme-hooks.d/                        per-component reload hooks

  theme-default/                              fallback baseline + current look
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
    .local/share/wallpapers/default.png
    .local/share/zsh/theme-colors.zsh
    meta.toml                                 name/description/accent/preview
    usr/share/sddm/themes/default/            optional; copied by polkit helper
    (SDDM Current= is written to /etc/sddm.conf.d/10-theme.conf by helper)

  theme-nord/                                 overlay — only files that differ
  theme-dracula/
  theme-template/                             NOT stowed; cp -r to create new

  install/                                    NOT stowed; VCS-tracked
    theme-apply-sddm                          root-owned after install
    org.marvin.theme-switch.policy            polkit action
    install.sh                                idempotent installer

  state/
    active                                    name of currently active theme
    previous                                  name of previous theme (for --rollback)
    log                                       switch log, rotated at 1 MB

  tests/
    *.bats                                    unit tests (bats-core)
    integration/run.sh                        Arch-container integration test
    manual-smoke.md                           checklist for live-system verification

  docs/superpowers/specs/                     design docs (this file lives here)
```

### Switch algorithm

```
active = $(cat state/active 2>/dev/null || echo default)
[ -d "theme-$new" ] || { error "theme '$new' not found"; exit 1; }

exec 200>state/lock
flock -n 200 || { error "theme-switch already running"; exit 1; }

trap 'stow -R theme-default; notify-send -u critical "switch failed"; exit 1' ERR

cd ~/hypr-dots
stow -D "theme-$active"
stow -R theme-default
[ "$new" != "default" ] && stow --override='.*' "theme-$new"

echo "$active" > state/previous
echo "$new"    > state/active

for hook in bin/theme-hooks.d/*.sh; do
  bash "$hook" "$new" || log WARN "hook $hook failed"
done

notify-send "Theme applied: $new"
```

### CLI surface

```
theme-switch <name>         apply a named theme
theme-switch --list         list available themes (excludes theme-template)
theme-switch --current      print active theme
theme-switch --dry-run X    show stow commands + hooks; do nothing
theme-switch --rollback     apply state/previous
```

### Reload hooks (in `bin/theme-hooks.d/`, run in lexical order)

| # | File                  | Action                                                                                        | Hot-reload |
| - | --------------------- | --------------------------------------------------------------------------------------------- | ---------- |
| 10 | `10-hyprland.sh`     | `hyprctl reload`                                                                              | yes        |
| 15 | `15-hyprpaper.sh`    | `hyprctl hyprpaper unload all` + `preload` + `wallpaper` for each monitor                      | yes        |
| 20 | `20-kitty.sh`        | For each `/tmp/kitty-*` socket: `kitten @ --to unix:$sock set-colors -a -c kitty.conf`         | yes        |
| 30 | `30-waybar.sh`       | `pkill -SIGUSR2 waybar`; fallback `pkill waybar && waybar &`                                   | yes        |
| 40 | `40-rofi.sh`         | no-op (next invocation reads file)                                                            | n/a        |
| 50 | `50-nvim.sh`         | Reads `colorscheme` from `meta.toml`; for each `$XDG_RUNTIME_DIR/nvim-*` socket: `nvim --server $sock --remote-send ':colorscheme <cs><CR>'` | yes |
| 60 | `60-gtk.sh`          | Reads `gtk_theme`/`icon_theme`/`cursor_theme` from `meta.toml`; `gsettings set` for each       | partial    |
| 70 | `70-cursor.sh`       | Reads `cursor_theme`/`cursor_size` from `meta.toml`; `hyprctl setcursor <theme> <size>`        | yes        |
| 80 | `80-zsh.sh`          | touch marker; `.zshrc precmd` re-sources `theme-colors.zsh` on next prompt                     | partial    |
| 90 | `90-hyprlock.sh`     | no-op (next lock reads file)                                                                  | n/a        |
| 95 | `95-sddm.sh`         | `pkexec /usr/local/bin/theme-apply-sddm <name>`                                               | next login |

Each hook checks `command -v <tool>` and exits 0 if the tool is missing, logging "skipped". Each hook runs under `set -e` in its own subshell; failures are logged but do not abort the switcher.

### Environment assumptions enforced by the design

- `hypr-base/.config/kitty/kitty.conf` contains:
  - `allow_remote_control socket-only`
  - `listen_on unix:/tmp/kitty-{kitty_pid}`
- `hypr-base/.config/nvim/lua/config/options.lua` calls
  `vim.fn.serverstart(vim.env.XDG_RUNTIME_DIR .. "/nvim-" .. vim.fn.getpid())`.
- `hypr-base/.zshrc` sources `~/.local/share/zsh/theme-colors.zsh` and has a `precmd` hook that re-sources it when a marker file is newer.
- Hyprland keybind: `bind = $mainMod, T, exec, ~/bin/theme-switch-rofi`.

### Rofi UI (`theme-switch-rofi`)

- Enumerates `theme-*/` in `~/hypr-dots/`, excluding `theme-template`.
- Reads `theme-<name>/meta.toml`: `name`, `description`, `accent`, `preview`, `colorscheme` (nvim colorscheme identifier), `gtk_theme`, `icon_theme`, `cursor_theme`, `cursor_size`.
- Renders dmenu-style list styled after `rofi/applets/type-5/style-1.rasi`, with a per-theme accent icon.
- Selection → **confirm prompt** (second rofi screen, Yes/No) → `theme-switch <name>` → close.
- Preview thumbnails generated on-demand with `magick` into `~/.cache/theme-switch/<name>.png`; falls back to an accent-color solid square.
- Picker itself uses the currently-active theme's `colors.rasi`, so it re-tints after each switch.
- If rofi unavailable, falls back to printing `theme-switch --list` and exits 1.

### SDDM — polkit-authorized helper

One-time install (idempotent `install/install.sh`):

```bash
sudo install -m 0755 ~/hypr-dots/install/theme-apply-sddm /usr/local/bin/
sudo install -m 0644 ~/hypr-dots/install/org.marvin.theme-switch.policy \
                      /usr/share/polkit-1/actions/
```

`theme-apply-sddm` (root-owned at `/usr/local/bin/theme-apply-sddm`):

1. Validates `$1` against `/home/marvin/hypr-dots/theme-$1/`; aborts on unknown theme.
2. If `theme-<name>/usr/share/sddm/themes/<name>/` exists, `rsync -a --delete` it into `/usr/share/sddm/themes/<name>/`.
3. Atomically writes `[Theme]\nCurrent=<name>\n` to `/etc/sddm.conf.d/10-theme.conf` via `install -m 0644`.

Polkit action `org.marvin.theme-switch.apply-sddm`:
- `exec.path` pinned to `/usr/local/bin/theme-apply-sddm`.
- `allow_active=yes`, `allow_inactive=no`, `allow_any=no` → no password prompt for the logged-in active-session user, denied otherwise.
- `exec.allow_gui=false`.

Security: helper refuses unknown theme names, hard-codes the user's dotfiles path, uses no shell eval, and scopes `rsync --delete` to exactly one theme directory.

## Error handling & edge cases

- **Fallback:** files absent from chosen theme stay pointing at `theme-default` (stow `--override` only re-points paths the overlay package provides; paths it omits remain owned by `theme-default` from the preceding `stow -R`). A sanity pass at end-of-switch walks `manifest.txt` and reports dangling symlinks (warn, don't abort).
- **Stow conflict** (non-symlink real file at a target path): switcher reports the offender and exits non-zero. Does not `--adopt`. Self-heals on next run via `stow -D && stow -R theme-default`.
- **Partial switch failure:** `trap ERR` runs `stow -R theme-default`, notifies, exits 1.
- **Hook failure:** logged, not fatal. Summary at end: "theme applied; N hooks failed: <names>".
- **Missing external tool:** hook checks `command -v`, skips gracefully.
- **Same-theme re-apply:** allowed; re-stows and re-runs hooks (useful after editing theme files).
- **Unknown theme name:** rejected before any filesystem change.
- **Concurrent switches:** flock on `state/lock`, second call fails fast.
- **SDDM helper missing:** hook notifies, returns 0 — next login keeps old SDDM theme.
- **Hyprland not running:** `hyprctl`-based hooks skip with notice; next Hyprland launch reads stowed configs normally.
- **Wallpaper file missing:** hyprpaper logs and keeps previous wallpaper; hook detects broken symlink via `readlink -e` and notifies.
- **Nvim without server socket:** hook skips; instance picks up new colorscheme on next launch or manual `:colorscheme`.
- **State corruption:** missing/unreadable `state/active` → assume `default`; no persistent damage.
- **Rollback:** one level, via `state/previous`. If `state/previous` is missing or empty, `theme-switch --rollback` exits 1 with "nothing to roll back to".

## Migration (one-time)

1. Branch `hypr-dots`; create `hypr-base/` and `theme-default/` with the target layout.
2. Move shared files into `hypr-base/` preserving path structure.
3. Move per-theme files (look_and_feel.conf, kitty.conf, waybar/{config,style.css}, rofi colors files, hyprlock.conf, hyprpaper.conf, nvim colorscheme plugin) into `theme-default/` preserving paths.
4. Copy `Viking_Rune.png` to `theme-default/.local/share/wallpapers/default.png`; update `theme-default/.config/hypr/hyprpaper.conf` to reference it.
5. Add `allow_remote_control socket-only` + `listen_on unix:/tmp/kitty-{kitty_pid}` to `hypr-base/.config/kitty/kitty.conf`.
6. Add nvim `serverstart` to `hypr-base/.config/nvim/lua/config/options.lua`.
7. Add `source ~/.local/share/zsh/theme-colors.zsh` + precmd re-source hook to `hypr-base/.zshrc`.
8. Scaffold `theme-template/` from `theme-default/` with palette values blanked and comments on customization points.
9. Scaffold `theme-nord/` and `theme-dracula/` from the template with their palettes filled in.
10. Un-stow the old flat `hypr-dots` package; `stow hypr-base theme-default`; reload Hyprland.
11. Run `install/install.sh` once to place the SDDM helper + polkit policy.
12. Bind `$mainMod, T` → `~/bin/theme-switch-rofi` in `keybinds.conf`.
13. Run manual smoke checklist (`tests/manual-smoke.md`).
14. Commit and push.

## Testing

### Unit tests — `bats-core`

`tests/*.bats` against a temp `mktemp -d` root, never touching live `~/`. Cover:
- `--list` output (excludes `theme-template`)
- `--current` reads `state/active` with default fallback
- unknown theme name → exit 1, stderr
- `--dry-run` prints plan, mutates nothing
- flock blocks concurrent runs
- hook discovery picks up a drop-in `99-test.sh`
- each hook: binary stubbed on PATH, assert correct args

### Integration test — Arch container

`tests/integration/run.sh` spins `archlinux:latest`, installs `stow bash bats-core`, bind-mounts the repo, runs:

```
stow hypr-base theme-default
theme-switch nord          && assert symlinks into theme-nord/
theme-switch dracula       && assert symlinks into theme-dracula/
theme-switch --rollback    && assert back on nord
```

Hooks skip gracefully (no Hyprland/waybar in container); assertions are on the symlink filesystem, not graphical behavior.

### Manual smoke checklist

`tests/manual-smoke.md` — run once on the live system after migration:

- [ ] `theme-switch default` applies cleanly, no visual artifacts
- [ ] Kitty recolors in place
- [ ] Waybar reloads config + style
- [ ] Rofi next launch shows new colors
- [ ] Hyprlock next lock shows new lock screen
- [ ] Wallpaper changes
- [ ] Nvim running instances re-`:colorscheme`
- [ ] GTK apps pick up theme
- [ ] SDDM on next reboot shows new login theme
- [ ] `theme-switch --rollback` reverts
- [ ] `$mainMod+T` opens rofi picker; confirm prompt applies

### CI

`.github/workflows/test.yml`:
- bats on ubuntu-latest with `stow` installed
- docker-based integration test

### Out of scope for tests

- Visual correctness of themes (by eye).
- SDDM login screen (would need a VM).
- Polkit prompt flow (covered by running `install/install.sh`).

## Open items (for the plan phase)

- Exact `nord` and `dracula` palettes to ship initially.
- Whether to bundle a custom SDDM theme directory per theme, or reuse existing installed SDDM themes by name.
- Exact nvim colorscheme plugins used per theme (must be declared in LazyVim plugin spec to be available offline).
- Initial icon/cursor theme per named theme.

These are content choices, not architectural ones; they get resolved during implementation.
