#!/usr/bin/env bash
# NiflVeil restore menu using tofi with wallust theming

CACHE_FILE="/tmp/minimize-state/windows.json"

# Check if cache file exists
if [ ! -f "$CACHE_FILE" ]; then
    notify-send "NiflVeil" "No minimized windows"
    exit 0
fi

# Get list of minimized windows from cache file
minimized_windows=$(jq -r '.[] | .display_title' "$CACHE_FILE" 2>/dev/null)

if [ -z "$minimized_windows" ]; then
    notify-send "NiflVeil" "No minimized windows"
    exit 0
fi

# Show menu with tofi (short prompt to minimize left spacing)
selected=$(echo "$minimized_windows" | tofi --config ~/.config/tofi/config --prompt-text "󰘸 ")

if [ -n "$selected" ]; then
    # Extract window address from the selected display_title by matching with JSON
    window_addr=$(jq -r --arg title "$selected" '.[] | select(.display_title == $title) | .address' "$CACHE_FILE" 2>/dev/null)

    if [ -n "$window_addr" ]; then
        ~/.local/bin/niflveil restore "$window_addr"
    fi
fi
