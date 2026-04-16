# Theme template

To create a new theme:
    cp -r theme-template theme-<name>
    $EDITOR theme-<name>/meta.toml
    # Edit the color files under theme-<name>/.config/.
    # Replace .local/share/wallpapers/default.png with your wallpaper.
    # Remove any file you don't want to override (it will fall back to theme-default).
