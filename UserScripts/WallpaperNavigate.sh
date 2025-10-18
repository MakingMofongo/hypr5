#!/bin/bash
# Sequential wallpaper navigation (Previous/Next)
# Uses the same mechanism as WallpaperRandom.sh but cycles through wallpapers in order

DIRECTION="${1:-next}" # "next" or "prev"
wallDIR="$HOME/Downloads/4K_Wallpaper_Dump_REUPLOAD"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
CACHE_DIR="$HOME/.cache/wallust_preload"
CURRENT_WALLPAPER_FILE="$CACHE_DIR/current_wallpaper.txt"
WALLPAPER_INDEX_FILE="$CACHE_DIR/wallpaper_index.txt"

# Get all wallpaper files
shopt -s nullglob
PICS=("${wallDIR}"/*.{jpg,jpeg,png,webp,gif})
shopt -u nullglob

# Exit if no wallpapers found
if [ ${#PICS[@]} -eq 0 ]; then
    notify-send "Wallpaper Error" "No wallpapers found in $wallDIR"
    exit 1
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Get current wallpaper and index
CURRENT_WALLPAPER=""
CURRENT_INDEX=0

if [ -f "$CURRENT_WALLPAPER_FILE" ]; then
    CURRENT_WALLPAPER=$(cat "$CURRENT_WALLPAPER_FILE")
fi

if [ -f "$WALLPAPER_INDEX_FILE" ]; then
    CURRENT_INDEX=$(cat "$WALLPAPER_INDEX_FILE")
fi

# Find current wallpaper in array if it exists
if [ -n "$CURRENT_WALLPAPER" ]; then
    for i in "${!PICS[@]}"; do
        if [ "${PICS[$i]}" = "$CURRENT_WALLPAPER" ]; then
            CURRENT_INDEX=$i
            break
        fi
    done
fi

# Calculate next/previous index
TOTAL_PICS=${#PICS[@]}
NEW_INDEX=$CURRENT_INDEX

if [ "$DIRECTION" = "next" ]; then
    NEW_INDEX=$(( (CURRENT_INDEX + 1) % TOTAL_PICS ))
elif [ "$DIRECTION" = "prev" ]; then
    NEW_INDEX=$(( (CURRENT_INDEX - 1 + TOTAL_PICS) % TOTAL_PICS ))
fi

# Get the new wallpaper
NEW_WALLPAPER="${PICS[$NEW_INDEX]}"

# Ensure swww is running
swww query || swww-daemon --format xrgb

# Set wallpaper IMMEDIATELY
swww img "${NEW_WALLPAPER}" --transition-fps 60 --transition-type fade --transition-duration 0.3 --transition-bezier .25,.1,.25,1

# Save current wallpaper and index
echo "$NEW_WALLPAPER" > "$CURRENT_WALLPAPER_FILE"
echo "$NEW_INDEX" > "$WALLPAPER_INDEX_FILE"

# Everything else happens in background after wallpaper is set
{
    # Get wallpaper hash
    WALLPAPER_HASH=$(basename "$NEW_WALLPAPER" | md5sum | cut -d' ' -f1)
    PRELOAD_MARKER="$CACHE_DIR/${WALLPAPER_HASH}.ready"

    # Use pre-extracted colors if available
    if [ -f "$PRELOAD_MARKER" ]; then
        cp "$CACHE_DIR/${WALLPAPER_HASH}_colors-waybar.css" "$HOME/.config/waybar/wallust/colors-waybar.css" 2>/dev/null
        cp "$CACHE_DIR/${WALLPAPER_HASH}_colors-rofi.rasi" "$HOME/.config/rofi/wallust/colors-rofi.rasi" 2>/dev/null
        cp "$CACHE_DIR/${WALLPAPER_HASH}_colors-hyprland.conf" "$HOME/.config/hypr/wallust/wallust-hyprland.conf" 2>/dev/null
        cp "$CACHE_DIR/${WALLPAPER_HASH}_colors-cava" "$HOME/.config/cava/config" 2>/dev/null
        cp "$CACHE_DIR/${WALLPAPER_HASH}_colors-kitty.conf" "$HOME/.config/kitty/kitty-themes/01-Wallust.conf" 2>/dev/null
        touch "$HOME/.config/waybar/wallust/colors-waybar.css"
    else
        # Extract colors on-the-fly
        "$SCRIPTSDIR/WallustSwww.sh"
        sleep 0.2

        # Cache the colors for future use
        cp "$HOME/.config/waybar/wallust/colors-waybar.css" "$CACHE_DIR/${WALLPAPER_HASH}_colors-waybar.css" 2>/dev/null
        cp "$HOME/.config/rofi/wallust/colors-rofi.rasi" "$CACHE_DIR/${WALLPAPER_HASH}_colors-rofi.rasi" 2>/dev/null
        cp "$HOME/.config/hypr/wallust/wallust-hyprland.conf" "$CACHE_DIR/${WALLPAPER_HASH}_colors-hyprland.conf" 2>/dev/null
        cp "$HOME/.config/cava/config" "$CACHE_DIR/${WALLPAPER_HASH}_colors-cava" 2>/dev/null
        cp "$HOME/.config/kitty/kitty-themes/01-Wallust.conf" "$CACHE_DIR/${WALLPAPER_HASH}_colors-kitty.conf" 2>/dev/null
        touch "$PRELOAD_MARKER"
    fi

    "$SCRIPTSDIR/Refresh.sh"

    # Send notification with wallpaper name
    WALLPAPER_NAME=$(basename "$NEW_WALLPAPER")
    notify-send -t 2000 "Wallpaper Changed" "$WALLPAPER_NAME ($((NEW_INDEX + 1))/$TOTAL_PICS)"
} &
