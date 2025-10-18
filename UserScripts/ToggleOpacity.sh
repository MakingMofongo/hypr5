#!/bin/bash
# Script to toggle window opacity/transparency

# State file to track opacity state per window
STATE_DIR="$HOME/.cache/hypr"
mkdir -p "$STATE_DIR"

# Get active window info
window_info=$(hyprctl activewindow -j)
window_addr=$(echo "$window_info" | jq -r '.address')
window_class=$(echo "$window_info" | jq -r '.class')

if [ "$window_addr" = "null" ] || [ -z "$window_addr" ]; then
    notify-send "Window Opacity" "No active window"
    exit 1
fi

STATE_FILE="$STATE_DIR/opacity_state_${window_addr}"

# Get default opacity based on window class/tags (from WindowRules.conf)
# Default values if no rule matches
default_active=0.9
default_inactive=0.8

# Check window class and set appropriate defaults
case "$window_class" in
    # Browsers (tag:browser) - 0.9 0.7
    *[Cc]hrome*|*[Ff]irefox*|*[Bb]rave*|*[Cc]hromium*|*[Ee]dge*|zen*)
        default_active=0.9
        default_inactive=0.7
        ;;
    # Terminals (tag:terminal) - 0.8 0.7
    *kitty*|*[Aa]lacritty*)
        default_active=0.8
        default_inactive=0.7
        ;;
    # Projects/IDEs (tag:projects) - 0.9 0.8
    *codium*|*VSCode*|*VSCodium*|jetbrains*|cursor*)
        default_active=0.9
        default_inactive=0.8
        ;;
    # IM apps (tag:im) - 0.94 0.86
    *[Dd]iscord*|*[Ww]eb[Cc]ord*|*[Vv]esktop*|*[Ff]erdium*|*[Ww]hatsapp*|ZapZap*|*[Tt]elegram*|*teams*)
        default_active=0.94
        default_inactive=0.86
        ;;
    # Multimedia (tag:multimedia) - 0.94 0.86
    *[Aa]udacious*)
        default_active=0.94
        default_inactive=0.86
        ;;
    # File managers (tag:file-manager) - 0.9 0.8
    *[Tt]hunar*|*[Nn]autilus*|*[Pp]cmanfm*|*Warp*)
        default_active=0.9
        default_inactive=0.8
        ;;
    # Settings (tag:settings) - 0.8 0.7
    *wihotspot*|*[Bb]aobab*|*gnome-disks*|*pavucontrol*|*pwvucontrol*|qt5ct|qt6ct|*[Yy]ad*|*[Rr]ofi*|*polkit*)
        default_active=0.8
        default_inactive=0.7
        ;;
    # Viewers (tag:viewer) - 0.82 0.75
    *gnome-system-monitor*|*SystemMonitor*|*MissionCenter*|evince*|eog*|*Loupe*)
        default_active=0.82
        default_inactive=0.75
        ;;
    # Wallpaper apps (tag:wallpaper) - 0.9 0.7
    *[Ww]aytrogen*)
        default_active=0.9
        default_inactive=0.7
        ;;
    # Text editors - 0.8 0.7
    gedit*|*TextEditor*|mousepad*)
        default_active=0.8
        default_inactive=0.7
        ;;
    # Other specific apps
    deluge*|im.riot.Riot*|seahorse*)
        default_active=0.9
        default_inactive=0.8
        ;;
esac

# Check current state
if [ -f "$STATE_FILE" ]; then
    # Currently opaque, restore to default transparency and LOCK it
    hyprctl setprop address:${window_addr} alpha ${default_active} lock
    hyprctl setprop address:${window_addr} alphainactive ${default_inactive} lock
    rm "$STATE_FILE"
    notify-send "Window Opacity" "Transparency enabled (${default_active})"
else
    # Currently transparent, make opaque and LOCK
    hyprctl setprop address:${window_addr} alpha 1.0 lock
    hyprctl setprop address:${window_addr} alphainactive 1.0 lock
    touch "$STATE_FILE"
    notify-send "Window Opacity" "Transparency disabled (100% opaque)"
fi
