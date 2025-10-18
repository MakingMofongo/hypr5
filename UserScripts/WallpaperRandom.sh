#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Random Wallpaper ( CTRL ALT W) - INSTANT WALLPAPER CHANGE

wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
CACHE_DIR="$HOME/.cache/wallust_preload"
NEXT_WALLPAPER_FILE="$CACHE_DIR/next_wallpaper.txt"

# INSTANT WALLPAPER: Check if we have a pre-selected wallpaper ready
if [ -f "$NEXT_WALLPAPER_FILE" ]; then
    # Use pre-selected wallpaper for INSTANT switch
    RANDOMPICS=$(cat "$NEXT_WALLPAPER_FILE")

    # Set wallpaper IMMEDIATELY (no other operations first)
    swww img "${RANDOMPICS}" --transition-fps 60 --transition-type fade --transition-duration 0 --transition-bezier .25,.1,.25,1

    # Everything else happens in background after wallpaper is set
    {
        # Get wallpaper hash
        WALLPAPER_HASH=$(basename "$RANDOMPICS" | md5sum | cut -d' ' -f1)
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
        fi

        "$SCRIPTSDIR/Refresh.sh"

        # Pre-select and pre-extract NEXT wallpaper
        shopt -s nullglob
        PICS=("${wallDIR}"/*.{jpg,jpeg,png,webp,gif})
        shopt -u nullglob
        NEXT_WALLPAPER="${PICS[RANDOM % ${#PICS[@]}]}"
        echo "$NEXT_WALLPAPER" > "$NEXT_WALLPAPER_FILE"

        NEXT_HASH=$(basename "$NEXT_WALLPAPER" | md5sum | cut -d' ' -f1)
        NEXT_MARKER="$CACHE_DIR/${NEXT_HASH}.ready"

        if [ ! -f "$NEXT_MARKER" ]; then
            wallust run "$NEXT_WALLPAPER" -s > /dev/null 2>&1
            cp "$HOME/.config/waybar/wallust/colors-waybar.css" "$CACHE_DIR/${NEXT_HASH}_colors-waybar.css" 2>/dev/null
            cp "$HOME/.config/rofi/wallust/colors-rofi.rasi" "$CACHE_DIR/${NEXT_HASH}_colors-rofi.rasi" 2>/dev/null
            cp "$HOME/.config/hypr/wallust/wallust-hyprland.conf" "$CACHE_DIR/${NEXT_HASH}_colors-hyprland.conf" 2>/dev/null
            cp "$HOME/.config/cava/config" "$CACHE_DIR/${NEXT_HASH}_colors-cava" 2>/dev/null
            cp "$HOME/.config/kitty/kitty-themes/01-Wallust.conf" "$CACHE_DIR/${NEXT_HASH}_colors-kitty.conf" 2>/dev/null
            touch "$NEXT_MARKER"
            # Restore current wallpaper colors
            wallust run "$RANDOMPICS" -s > /dev/null 2>&1
        fi
    } &

    exit 0
fi

# FIRST RUN: No pre-selected wallpaper yet, initialize system
mkdir -p "$CACHE_DIR"
shopt -s nullglob
PICS=("${wallDIR}"/*.{jpg,jpeg,png,webp,gif})
shopt -u nullglob
RANDOMPICS="${PICS[RANDOM % ${#PICS[@]}]}"

# Set wallpaper FIRST (instant!)
swww query || swww-daemon --format xrgb
swww img "${RANDOMPICS}" --transition-fps 60 --transition-type fade --transition-duration 0 --transition-bezier .25,.1,.25,1

# Everything else in background
{
    # Extract colors
    "$SCRIPTSDIR/WallustSwww.sh"
    sleep 0.2
    "$SCRIPTSDIR/Refresh.sh"

    # Pre-select and pre-extract NEXT wallpaper for instant future switches
    NEXT_WALLPAPER="${PICS[RANDOM % ${#PICS[@]}]}"
    echo "$NEXT_WALLPAPER" > "$NEXT_WALLPAPER_FILE"

    NEXT_HASH=$(basename "$NEXT_WALLPAPER" | md5sum | cut -d' ' -f1)
    NEXT_MARKER="$CACHE_DIR/${NEXT_HASH}.ready"

    if [ ! -f "$NEXT_MARKER" ]; then
        wallust run "$NEXT_WALLPAPER" -s > /dev/null 2>&1
        cp "$HOME/.config/waybar/wallust/colors-waybar.css" "$CACHE_DIR/${NEXT_HASH}_colors-waybar.css" 2>/dev/null
        cp "$HOME/.config/rofi/wallust/colors-rofi.rasi" "$CACHE_DIR/${NEXT_HASH}_colors-rofi.rasi" 2>/dev/null
        cp "$HOME/.config/hypr/wallust/wallust-hyprland.conf" "$CACHE_DIR/${NEXT_HASH}_colors-hyprland.conf" 2>/dev/null
        cp "$HOME/.config/cava/config" "$CACHE_DIR/${NEXT_HASH}_colors-cava" 2>/dev/null
        cp "$HOME/.config/kitty/kitty-themes/01-Wallust.conf" "$CACHE_DIR/${NEXT_HASH}_colors-kitty.conf" 2>/dev/null
        touch "$NEXT_MARKER"
        # Restore current colors
        wallust run "$RANDOMPICS" -s > /dev/null 2>&1
    fi
} &

