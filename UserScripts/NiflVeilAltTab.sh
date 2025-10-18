#!/usr/bin/env bash
# NiflVeil Alt+Tab style window switcher

CACHE_FILE="/tmp/minimize-state/windows.json"
STATE_FILE="/tmp/niflveil-alttab-state"

# Check if cache file exists
if [ ! -f "$CACHE_FILE" ]; then
    exit 0
fi

# Parse minimized windows
windows_json=$(cat "$CACHE_FILE" 2>/dev/null)
window_count=$(echo "$windows_json" | jq 'length' 2>/dev/null)

if [ "$window_count" -eq 0 ] || [ -z "$window_count" ]; then
    exit 0
fi

# Check if we're already cycling
if [ -f "$STATE_FILE" ]; then
    current_index=$(cat "$STATE_FILE")
    # Move to next window
    next_index=$(( (current_index + 1) % window_count ))
    echo "$next_index" > "$STATE_FILE"
else
    # Start cycling from first window
    echo "0" > "$STATE_FILE"
    next_index=0
fi

# Get the window address at the current index
window_addr=$(echo "$windows_json" | jq -r ".[$next_index].address" 2>/dev/null)
window_title=$(echo "$windows_json" | jq -r ".[$next_index].display_title" 2>/dev/null)

# Show notification with current selection
notify-send -t 1000 "NiflVeil" "$window_title"

# Set a timer to restore the window after 500ms of no input
(
    sleep 0.5
    if [ -f "$STATE_FILE" ]; then
        index=$(cat "$STATE_FILE")
        addr=$(echo "$windows_json" | jq -r ".[$index].address" 2>/dev/null)
        if [ -n "$addr" ]; then
            ~/.local/bin/niflveil restore "$addr"
        fi
        rm -f "$STATE_FILE"
    fi
) &
