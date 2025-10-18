#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust - OPTIMIZED FOR INSTANT UPDATES

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
    [ -e "$1" ]
}

# PERFORMANCE: With reload_style_on_change enabled in waybar config,
# waybar will automatically detect CSS changes and reload instantly.
# We don't need to signal it anymore!

# Just touch the CSS file to ensure inotify triggers if needed
if [ -f "$HOME/.config/waybar/wallust/colors-waybar.css" ]; then
    touch "$HOME/.config/waybar/wallust/colors-waybar.css"
fi

# Signal swaync to reload CSS only
if pidof swaync >/dev/null; then
    swaync-client --reload-css > /dev/null 2>&1 &
fi

# Reload ags if running (faster than quit & restart)
if pidof ags >/dev/null; then
    (ags -q && sleep 0.05 && ags) &
fi

# Relaunching rainbow borders if the script exists
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    (pkill -f RainbowBorders.sh && sleep 0.05 && ${UserScripts}/RainbowBorders.sh) &
fi

exit 0