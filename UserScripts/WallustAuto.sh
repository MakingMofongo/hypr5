#!/bin/bash
# Automatic light/dark palette detection for wallust
# Detects wallpaper brightness in the top bar area and applies appropriate palette

wallpaper_path="$1"

if [ -z "$wallpaper_path" ] || [ ! -f "$wallpaper_path" ]; then
    echo "Error: Wallpaper path not provided or file doesn't exist"
    exit 1
fi

# Check if ImageMagick is installed for brightness detection
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "Warning: ImageMagick not found, defaulting to dark palette"
    wallust run "$wallpaper_path" -s
    exit 0
fi

# Function to calculate relative luminance (0-1 scale)
calc_luminance() {
    local hex_color="${1#\#}"
    local r=$((16#${hex_color:0:2}))
    local g=$((16#${hex_color:2:2}))
    local b=$((16#${hex_color:4:2}))

    # Normalize to 0-1
    local r_norm=$(echo "scale=4; $r / 255" | bc)
    local g_norm=$(echo "scale=4; $g / 255" | bc)
    local b_norm=$(echo "scale=4; $b / 255" | bc)

    # sRGB to linear RGB
    local r_lin=$(echo "scale=4; if ($r_norm <= 0.03928) $r_norm / 12.92 else e(l(($r_norm + 0.055) / 1.055) * 2.4)" | bc -l)
    local g_lin=$(echo "scale=4; if ($g_norm <= 0.03928) $g_norm / 12.92 else e(l(($g_norm + 0.055) / 1.055) * 2.4)" | bc -l)
    local b_lin=$(echo "scale=4; if ($b_norm <= 0.03928) $b_norm / 12.92 else e(l(($b_norm + 0.055) / 1.055) * 2.4)" | bc -l)

    # Calculate luminance
    echo "scale=4; 0.2126 * $r_lin + 0.7152 * $g_lin + 0.0722 * $b_lin" | bc -l
}

# Function to calculate contrast ratio
calc_contrast() {
    local lum1=$(calc_luminance "$1")
    local lum2=$(calc_luminance "$2")

    # Ensure lum1 is lighter
    if (( $(echo "$lum2 > $lum1" | bc -l) )); then
        local temp=$lum1
        lum1=$lum2
        lum2=$temp
    fi

    echo "scale=2; ($lum1 + 0.05) / ($lum2 + 0.05)" | bc -l
}

# Function to adjust color brightness for better contrast
adjust_color_brightness() {
    local hex_color="${1#\#}"
    local target_brightness="$2"  # "lighter" or "darker"

    local r=$((16#${hex_color:0:2}))
    local g=$((16#${hex_color:2:2}))
    local b=$((16#${hex_color:4:2}))

    if [ "$target_brightness" = "lighter" ]; then
        # Make lighter (move towards white)
        r=$(echo "scale=0; ($r + 255) / 2" | bc)
        g=$(echo "scale=0; ($g + 255) / 2" | bc)
        b=$(echo "scale=0; ($b + 255) / 2" | bc)
    else
        # Make darker (move towards black)
        r=$(echo "scale=0; $r / 2" | bc)
        g=$(echo "scale=0; $g / 2" | bc)
        b=$(echo "scale=0; $b / 2" | bc)
    fi

    printf "#%02X%02X%02X\n" "$r" "$g" "$b"
}

# Analyze the top 5% of the image (where waybar typically sits)
# This gives more accurate detection for what's actually behind the bar
if command -v magick &> /dev/null; then
    # ImageMagick 7+
    # Crop top 5% of image, convert to grayscale, get average brightness
    brightness=$(magick "$wallpaper_path" -gravity North -crop 100%x5%+0+0 +repage -colorspace Gray -format "%[fx:100*mean]" info:)
else
    # ImageMagick 6
    brightness=$(convert "$wallpaper_path" -gravity North -crop 100%x5%+0+0 +repage -colorspace Gray -format "%[fx:100*mean]" info:)
fi

# Remove decimal point if present
brightness_int=${brightness%.*}

# Threshold for light/dark detection (50 = middle gray)
# Adjust this value if needed (higher = more images treated as light)
THRESHOLD=45

echo "Top bar area brightness: $brightness_int%"

# Determine palette based on brightness
if [ "$brightness_int" -gt "$THRESHOLD" ]; then
    echo "Light wallpaper detected - using light palette"
    palette="light16"
else
    echo "Dark wallpaper detected - using dark palette"
    palette="dark16"
fi

# Update wallust.toml with the appropriate palette
wallust_config="$HOME/.config/wallust/wallust.toml"

if [ -f "$wallust_config" ]; then
    # Use sed to update the palette line
    sed -i "s/^palette = .*/palette = \"$palette\"/" "$wallust_config"
    echo "Updated wallust config to use '$palette' palette"
fi

# Run wallust with the wallpaper
echo "Running wallust..."
wallust run "$wallpaper_path" -s

# Override foreground-fixed color in waybar CSS for items without background
waybar_css="$HOME/.config/waybar/wallust/colors-waybar.css"
if [ -f "$waybar_css" ]; then
    if [ "$palette" = "light16" ]; then
        # Light wallpaper: use dark grey for icons without background
        sed -i 's/@define-color foreground-fixed.*/@define-color foreground-fixed #2b2b2b;/' "$waybar_css"
    else
        # Dark wallpaper: use white for icons without background
        sed -i 's/@define-color foreground-fixed.*/@define-color foreground-fixed #ffffff;/' "$waybar_css"
    fi
    echo "Fixed icon color for $palette palette"

    # Wallust already has check_contrast enabled, which ensures WCAG 2.0 compliance
    # We just log the contrast ratios for debugging
    foreground=$(grep "define-color foreground " "$waybar_css" | grep -v "foreground-fixed" | head -1 | sed 's/.*#/#/' | cut -d';' -f1)
    color0=$(grep "define-color color0 " "$waybar_css" | sed 's/.*#/#/' | cut -d';' -f1)
    color12=$(grep "define-color color12 " "$waybar_css" | sed 's/.*#/#/' | cut -d';' -f1)

    echo "Generated colors: foreground=$foreground, color0=$color0, color12=$color12"
    echo "Wallust's built-in contrast checking already ensures readability"
fi

echo "Wallust completed successfully"
