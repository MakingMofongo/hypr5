#!/usr/bin/env bash
# Tofi Keybind Search - Search and execute Hyprland keybinds
# Created for quick keybind discovery and execution
#
# Usage:
#   TofiKeybindSearch.sh          # Show search menu (uses cache)
#   TofiKeybindSearch.sh --rebuild # Rebuild description cache

# Config file paths
CONFIG_FILES=(
    "$HOME/.config/hypr/configs/Keybinds.conf"
    "$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"
)
DESCRIPTIONS_FILE="$HOME/.config/hypr/UserConfigs/keybind_descriptions.conf"
CACHE_FILE="$HOME/.cache/hypr/keybind_descriptions_cache"

# Function to build description cache
build_cache() {
    echo "Building keybind description cache..." >&2

    # Create cache directory if it doesn't exist
    mkdir -p "$(dirname "$CACHE_FILE")"

    # Temporary file for building cache
    local temp_cache="${CACHE_FILE}.tmp"
    > "$temp_cache"

    # Load inline comments from config files
    for config_file in "${CONFIG_FILES[@]}"; do
        if [ -f "$config_file" ]; then
            while IFS= read -r line; do
                # Match bind lines with comments
                if [[ "$line" =~ ^[[:space:]]*(bind|bindl|binde|bindr|bindm)[[:space:]=]+([^#]+)#[[:space:]]*(.+)$ ]]; then
                    bind_part="${BASH_REMATCH[2]}"
                    comment="${BASH_REMATCH[3]}"

                    # Extract key from bind definition
                    # Format: MODS, KEY, dispatcher, arg
                    if [[ "$bind_part" =~ ([^,]+),[[:space:]]*([^,]+),[[:space:]]*(.+) ]]; then
                        mods="${BASH_REMATCH[1]}"
                        key="${BASH_REMATCH[2]}"

                        # Normalize the key
                        key=$(echo "$key" | xargs)
                        mods=$(echo "$mods" | xargs)

                        # Write to cache with priority marker (inline=1)
                        echo "1|${mods}|${key}|${comment}" >> "$temp_cache"
                    fi
                fi
            done < "$config_file"
        fi
    done

    # Load manual descriptions from file (lower priority)
    if [ -f "$DESCRIPTIONS_FILE" ]; then
        while IFS='|' read -r modmask key desc; do
            # Skip comments and empty lines
            [[ "$modmask" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$modmask" ]] && continue

            # Write to cache with priority marker (manual=2)
            echo "2|${modmask}|${key}|${desc}" >> "$temp_cache"
        done < "$DESCRIPTIONS_FILE"
    fi

    # Move temp cache to final location
    mv "$temp_cache" "$CACHE_FILE"
    echo "Cache built: $CACHE_FILE" >&2
}

# Check if rebuild requested
if [ "$1" == "--rebuild" ]; then
    build_cache
    echo "Keybind description cache rebuilt successfully!"
    exit 0
fi

# Check if cache exists and is newer than config files
cache_needs_rebuild=false
if [ ! -f "$CACHE_FILE" ]; then
    cache_needs_rebuild=true
else
    # Check if any config file is newer than cache
    for config_file in "${CONFIG_FILES[@]}" "$DESCRIPTIONS_FILE"; do
        if [ -f "$config_file" ] && [ "$config_file" -nt "$CACHE_FILE" ]; then
            cache_needs_rebuild=true
            break
        fi
    done
fi

# Rebuild cache if needed
if [ "$cache_needs_rebuild" = true ]; then
    build_cache
fi

# Load descriptions from cache
declare -A inline_comments
declare -A descriptions
while IFS='|' read -r priority mods_or_mask key desc; do
    if [ "$priority" == "1" ]; then
        # Inline comment (uses mod notation like $mainMod)
        inline_comments["${mods_or_mask}|${key}"]="$desc"
    elif [ "$priority" == "2" ]; then
        # Manual description (uses modmask number)
        descriptions["${mods_or_mask}|${key}"]="$desc"
    fi
done < "$CACHE_FILE"

# Get all keybinds from hyprctl
keybinds=$(hyprctl binds -j)

# Parse and format keybinds: "MODIFIERS+KEY: description"
formatted_binds=$(echo "$keybinds" | jq -r '.[] |
    select(.dispatcher != "") |
    "\(.modmask // 0)|\(.key)|\(.dispatcher)|\(.arg // "")"' |
    while IFS='|' read -r modmask key dispatcher arg; do
        # Convert modmask to human-readable modifiers
        mods=""
        if [ $((modmask & 64)) -ne 0 ]; then mods="${mods}SUPER+"; fi
        if [ $((modmask & 4)) -ne 0 ]; then mods="${mods}SHIFT+"; fi
        if [ $((modmask & 8)) -ne 0 ]; then mods="${mods}CTRL+"; fi
        if [ $((modmask & 1)) -ne 0 ]; then mods="${mods}ALT+"; fi

        # Format the bind
        bind="${mods}${key}"

        # Hybrid lookup: inline comment → descriptions file → fallback
        # First, try to match with config file notation (e.g., "$mainMod|Q")
        desc=""

        # Build lookup keys for inline comments
        mod_lookup=""
        if [ $((modmask & 64)) -ne 0 ]; then mod_lookup="\$mainMod"; fi
        if [ $((modmask & 4)) -ne 0 ]; then
            [ -n "$mod_lookup" ] && mod_lookup="$mod_lookup SHIFT" || mod_lookup="SHIFT"
        fi
        if [ $((modmask & 8)) -ne 0 ]; then
            [ -n "$mod_lookup" ] && mod_lookup="$mod_lookup CTRL" || mod_lookup="CTRL"
        fi
        if [ $((modmask & 1)) -ne 0 ]; then
            [ -n "$mod_lookup" ] && mod_lookup="$mod_lookup ALT" || mod_lookup="ALT"
        fi

        # Try inline comment lookup with config notation
        if [ -n "$mod_lookup" ]; then
            comment_key="${mod_lookup}|${key}"
            desc="${inline_comments[$comment_key]}"
        fi

        # If not found in inline comments, try descriptions file
        if [ -z "$desc" ]; then
            lookup_key="${modmask}|${key}"
            desc="${descriptions[$lookup_key]}"
        fi

        # Final fallback: use dispatcher and arg
        if [ -z "$desc" ]; then
            if [ -n "$arg" ]; then
                desc="$dispatcher $arg"
            else
                desc="$dispatcher"
            fi
        fi

        # Add search keywords for better fuzzy matching
        # Common variations that should match
        search_keywords=""
        case "$desc" in
            *"Float Mode"*) search_keywords=" (floating toggle window)" ;;
            *"All Float"*) search_keywords=" (floating all workspace)" ;;
            *"fullscreen"*) search_keywords=" (full screen maximize)" ;;
            *"Fake fullscreen"*) search_keywords=" (full screen maximize)" ;;
            *"wallpaper"*) search_keywords=" (background image)" ;;
            *"screenshot"*) search_keywords=" (screen capture print)" ;;
            *"workspace"*) search_keywords=" (desktop virtual)" ;;
            *"transparency"*) search_keywords=" (opacity transparent)" ;;
            *"opacity"*) search_keywords=" (transparency transparent)" ;;
            *"blur"*) search_keywords=" (blurry effect)" ;;
            *"notification"*) search_keywords=" (notify alert)" ;;
            *"terminal"*) search_keywords=" (console shell command)" ;;
            *"browser"*) search_keywords=" (web firefox chrome)" ;;
            *"file manager"*) search_keywords=" (files explorer thunar)" ;;
            *"lock"*) search_keywords=" (screen lock secure)" ;;
            *"power menu"*) search_keywords=" (logout shutdown reboot)" ;;
            *"clipboard"*) search_keywords=" (copy paste history)" ;;
        esac

        # Store original command for execution
        # Output format: "BIND: description keywords |CMD| dispatcher|arg"
        echo "${bind}: ${desc}${search_keywords} |CMD| ${dispatcher}|${arg}"
    done | sort -u
)

# Show in tofi and get selection using dedicated config
# Strip out the command part before showing (only show readable text)
display_binds=$(echo "$formatted_binds" | sed 's/ |CMD|.*//')
selected=$(echo "$display_binds" | tofi --config ~/.config/tofi/keybind-search-config)

# If something was selected, extract and execute the command
if [ -n "$selected" ]; then
    # Find the corresponding full line with command info
    selected_bind=$(echo "$selected" | cut -d':' -f1)
    full_line=$(echo "$formatted_binds" | grep -F "${selected_bind}:")

    # Extract dispatcher and arg from the |CMD| section
    cmd_part=$(echo "$full_line" | grep -oP '\|CMD\| \K.*')
    dispatcher=$(echo "$cmd_part" | cut -d'|' -f1)
    arg=$(echo "$cmd_part" | cut -d'|' -f2-)

    # Execute the dispatcher
    if [ "$dispatcher" == "exec" ]; then
        # If it's exec, run the command directly
        eval "$arg" &
    else
        # Otherwise use hyprctl dispatch
        if [ -n "$arg" ] && [ "$arg" != "$dispatcher" ]; then
            hyprctl dispatch "$dispatcher" "$arg"
        else
            hyprctl dispatch "$dispatcher"
        fi
    fi
fi
