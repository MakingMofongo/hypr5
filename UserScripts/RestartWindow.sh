#!/bin/bash
# Script to restart the active window

# Get active window class and command
active_info=$(hyprctl activewindow -j)
window_class=$(echo "$active_info" | jq -r '.class')
window_pid=$(echo "$active_info" | jq -r '.pid')

# Get the command that started the process
if [ "$window_pid" != "null" ] && [ -n "$window_pid" ]; then
    # Try to get the command from /proc
    window_cmd=$(cat /proc/$window_pid/cmdline 2>/dev/null | tr '\0' ' ' | sed 's/ $//')

    if [ -n "$window_cmd" ]; then
        # Kill the window
        hyprctl dispatch killactive

        # Wait a moment for the window to close
        sleep 0.3

        # Relaunch the application
        $window_cmd &

        notify-send "Window Restarted" "Relaunched: $window_class"
    else
        notify-send "Restart Failed" "Could not determine command for: $window_class"
    fi
else
    notify-send "Restart Failed" "No active window found"
fi
