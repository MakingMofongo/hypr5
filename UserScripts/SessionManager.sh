#!/bin/bash
# Simple Hyprland session manager
# Saves and restores window positions and workspaces

SESSION_FILE="$HOME/.cache/hyprland-session.conf"
LOG_FILE="$HOME/.cache/hyprland-session.log"
SAVE_INTERVAL=60

# Map class names to executable commands
get_executable() {
    local class="$1"
    case "$class" in
        google-chrome|chrome*) echo "google-chrome" ;;
        cursor|Cursor) echo "cursor" ;;
        foot) echo "foot" ;;
        nemo|Nemo) echo "nemo" ;;
        discord|Discord) echo "discord" ;;
        Spotify|spotify) echo "spotify" ;;
        zed|Zed|dev.zed.Zed) echo "zed" ;;
        firefox|Firefox) echo "firefox" ;;
        *) echo "$class" ;;
    esac
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

save_session() {
    # Get all clients and generate exec-once commands (apps + workspaces only)
    echo "# Hyprland session saved at $(date)" > "$SESSION_FILE"

    hyprctl clients -j | jq -r '.[] |
        select(.class != "") |
        "exec-once = [workspace \(.workspace.id // 1) silent] \(.class)"' \
        >> "$SESSION_FILE" 2>/dev/null

    log "Session saved with $(grep -c "^exec-once" "$SESSION_FILE" 2>/dev/null || echo 0) windows"
}

restore_session() {
    if [ -f "$SESSION_FILE" ]; then
        log "Restoring session from $SESSION_FILE"

        # Execute each window command from the session file
        grep "^exec-once" "$SESSION_FILE" | while read -r line; do
            # Extract the class name (last word)
            class=$(echo "$line" | awk '{print $NF}')
            # Get the executable command
            executable=$(get_executable "$class")
            # Extract workspace number
            workspace=$(echo "$line" | sed -n 's/.*workspace \([0-9]*\).*/\1/p')

            # Build and execute the command
            cmd="[workspace $workspace silent] $executable"
            log "Restoring: $executable on workspace $workspace"
            hyprctl dispatch exec "$cmd"
            sleep 0.8  # Delay between launches
        done

        log "Session restoration complete"
    else
        log "No session file found, skipping restore"
    fi
}

# Main loop
case "${1:-default}" in
    save-only)
        while true; do
            save_session
            sleep "$SAVE_INTERVAL"
        done
        ;;
    save-and-exit)
        save_session
        exit 0
        ;;
    load-and-exit)
        restore_session
        exit 0
        ;;
    default|*)
        # Restore on start, then save periodically
        restore_session
        while true; do
            sleep "$SAVE_INTERVAL"
            save_session
        done
        ;;
esac
