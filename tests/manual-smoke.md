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
