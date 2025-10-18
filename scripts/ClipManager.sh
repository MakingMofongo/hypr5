#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Clipboard Manager. This script uses cliphist, rofi, and wl-copy.

# Variables
rofi_theme="$HOME/.config/rofi/config-clipboard.rasi"
msg='<span size="small" alpha="60%">Ctrl+Del: delete entry  •  Alt+Del: clear all</span>'
# Actions:
# CTRL Del to delete an entry
# ALT Del to wipe clipboard contents

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

# Create a temporary directory for image previews
tmp_dir="/tmp/cliphist-previews-$$"
mkdir -p "$tmp_dir"

# Function to clean up temp directory
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

# Process cliphist list to show image previews
process_list() {
    cliphist list | while IFS= read -r line; do
        # Check if this entry contains binary data (image)
        if echo "$line" | grep -q '\[\[ binary data'; then
            # Extract the ID (first field), size, format, and dimensions
            id=$(echo "$line" | awk '{print $1}')
            size=$(echo "$line" | grep -oP '\[\[ binary data \K[0-9]+ [KMG]iB')
            format=$(echo "$line" | grep -oP '(png|jpg|jpeg|gif|webp|bmp)' | head -1)
            dimensions=$(echo "$line" | grep -oP '[0-9]+x[0-9]+')

            # Create thumbnail image for rofi icon
            preview_img="$tmp_dir/${id}.${format:-png}"
            if [ ! -f "$preview_img" ]; then
                echo "$line" | cliphist decode > "$preview_img" 2>/dev/null
            fi

            # Output with icon path (rofi null-separated format)
            printf "%s  •  %s\0icon\x1f%s\n" "$format" "$dimensions" "$preview_img"
        else
            # For text entries, show truncated preview (no multiline support in rofi)
            id=$(echo "$line" | awk '{print $1}')
            full_text=$(echo "$line" | cut -d$'\t' -f2- | tr '\n' ' ')

            # Truncate to ~150 chars for wider menu
            if [ ${#full_text} -gt 150 ]; then
                display_text=$(echo "$full_text" | head -c 150)...
            else
                display_text="$full_text"
            fi

            # Use text document icon for text entries
            printf "%s\0icon\x1f/tmp/text_icon.png\n" "$display_text"
        fi
    done
}

while true; do
    result=$(
        rofi -i -dmenu \
            -kb-custom-1 "Control-Delete" \
            -kb-custom-2 "Alt-Delete" \
            -show-icons \
            -markup-rows \
            -config $rofi_theme < <(process_list) \
			-mesg "$msg"
    )

    case "$?" in
        1)
            exit
            ;;
        0)
            case "$result" in
                "")
                    continue
                    ;;
                *)
                    # Handle image entries (format: "png  •  1920x1080")
                    if echo "$result" | grep -q '•'; then
                        # This is an image entry - need to find it in cliphist by matching dimensions
                        dimensions=$(echo "$result" | awk -F'•' '{print $2}' | xargs)
                        format=$(echo "$result" | awk -F'•' '{print $1}' | xargs)

                        # Find the matching entry in cliphist by dimensions
                        id=$(cliphist list | grep "\[\[ binary data.*${dimensions}" | head -1 | awk '{print $1}')

                        # Map format to MIME type
                        case "$format" in
                            png) mime="image/png" ;;
                            jpg|jpeg) mime="image/jpeg" ;;
                            gif) mime="image/gif" ;;
                            webp) mime="image/webp" ;;
                            *) mime="image/png" ;;  # Default fallback
                        esac

                        # Find the matching line in cliphist by ID and decode it
                        # Copy to both Wayland (wl-copy) and X11 (xclip) clipboards for compatibility
                        temp_img="/tmp/cliphist_restore_$$.${format}"
                        cliphist list | awk -v id="$id" '$1 == id' | cliphist decode > "$temp_img"
                        wl-copy --type "$mime" < "$temp_img"
                        xclip -selection clipboard -t "$mime" -i "$temp_img"
                        rm -f "$temp_img"

                        # Auto-paste after copying (instant)
                        wtype -M ctrl -P v -m ctrl -p v &
                    else
                        # Regular text entry - find by matching first line of text content
                        search_text=$(echo "$result" | head -1 | sed 's/\.\.\.$//' | xargs)  # Get first line, remove trailing ...
                        # Find the first matching entry in cliphist
                        cliphist list | grep -F "$search_text" | head -1 | cliphist decode | wl-copy

                        # Auto-paste after copying (instant)
                        wtype -M ctrl -P v -m ctrl -p v &
                    fi
                    exit
                    ;;
            esac
            ;;
        10)
            # Handle deletion for both text and image entries
            if echo "$result" | grep -q '•'; then
                # Image entry - find by dimensions
                dimensions=$(echo "$result" | awk -F'•' '{print $2}' | xargs)
                id=$(cliphist list | grep "\[\[ binary data.*${dimensions}" | head -1 | awk '{print $1}')
                cliphist list | awk -v id="$id" '$1 == id' | cliphist delete
            else
                # Text entry - find by matching first line of text content
                search_text=$(echo "$result" | head -1 | sed 's/\.\.\.$//' | xargs)
                cliphist list | grep -F "$search_text" | head -1 | cliphist delete
            fi
            ;;
        11)
            cliphist wipe
            ;;
    esac
done

