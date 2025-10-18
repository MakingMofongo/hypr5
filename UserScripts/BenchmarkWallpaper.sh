#!/bin/bash
# Benchmark script for wallpaper switching performance

wallDIR="$HOME/Downloads/4K_Wallpaper_Dump_REUPLOAD"
CACHE_DIR="$HOME/.cache/wallust_preload"
NEXT_WALLPAPER_FILE="$CACHE_DIR/next_wallpaper.txt"

echo "====================================="
echo "Wallpaper Switching Benchmark"
echo "====================================="
echo ""

# Test 1: Script startup time
echo "[Test 1] Bash script startup overhead"
START=$(date +%s%N)
bash -c "exit 0"
END=$(date +%s%N)
STARTUP_TIME=$(( (END - START) / 1000000 ))
echo "  Result: ${STARTUP_TIME}ms"
echo ""

# Test 2: File read time (simulating cache read)
echo "[Test 2] Cache file read time (cat command)"
mkdir -p "$CACHE_DIR"
echo "test" > "$CACHE_DIR/benchmark_test.txt"
START=$(date +%s%N)
DUMMY=$(cat "$CACHE_DIR/benchmark_test.txt")
END=$(date +%s%N)
READ_TIME=$(( (END - START) / 1000000 ))
echo "  Result: ${READ_TIME}ms"
rm "$CACHE_DIR/benchmark_test.txt"
echo ""

# Test 3: Random selection from array
echo "[Test 3] Wallpaper random selection"
shopt -s nullglob
PICS=("${wallDIR}"/*.{jpg,jpeg,png,webp,gif})
shopt -u nullglob
NUM_WALLPAPERS=${#PICS[@]}
echo "  Found: ${NUM_WALLPAPERS} wallpapers"
START=$(date +%s%N)
RANDOMPICS="${PICS[RANDOM % ${#PICS[@]}]}"
END=$(date +%s%N)
RANDOM_TIME=$(( (END - START) / 1000000 ))
echo "  Result: ${RANDOM_TIME}ms"
echo ""

# Test 4: swww img command execution time (actual wallpaper switch)
echo "[Test 4] swww wallpaper switch (with 0.3s fade)"
if [ -n "$RANDOMPICS" ] && [ -f "$RANDOMPICS" ]; then
    START=$(date +%s%N)
    swww img "${RANDOMPICS}" --transition-fps 60 --transition-type fade --transition-duration 0.3 --transition-bezier .25,.1,.25,1 2>/dev/null
    SWWW_EXIT=$?
    END=$(date +%s%N)
    SWWW_TIME=$(( (END - START) / 1000000 ))
    echo "  Result: ${SWWW_TIME}ms (includes 300ms fade animation)"
    echo "  Command overhead: $((SWWW_TIME - 300))ms"
else
    echo "  SKIP: No wallpapers found"
    SWWW_TIME=0
fi
echo ""

# Test 5: Pre-cached wallpaper path (fast path simulation)
echo "[Test 5] Fast path simulation (pre-cached wallpaper)"
if [ ${NUM_WALLPAPERS} -gt 0 ]; then
    # Setup: Pre-select a wallpaper
    NEXT_WALLPAPER="${PICS[RANDOM % ${#PICS[@]}]}"
    echo "$NEXT_WALLPAPER" > "$NEXT_WALLPAPER_FILE"

    # Measure: Read and use pre-selected wallpaper
    START=$(date +%s%N)
    CACHED_PIC=$(cat "$NEXT_WALLPAPER_FILE")
    END=$(date +%s%N)
    FAST_PATH_TIME=$(( (END - START) / 1000000 ))
    echo "  Pre-cached read: ${FAST_PATH_TIME}ms"

    # Actual switch
    START=$(date +%s%N)
    swww img "${CACHED_PIC}" --transition-fps 60 --transition-type fade --transition-duration 0.3 --transition-bezier .25,.1,.25,1 2>/dev/null
    END=$(date +%s%N)
    FAST_SWITCH_TIME=$(( (END - START) / 1000000 ))
    echo "  Fast path switch: ${FAST_SWITCH_TIME}ms"

    TOTAL_FAST=$(( STARTUP_TIME + FAST_PATH_TIME + FAST_SWITCH_TIME ))
    echo "  Total fast path: ${TOTAL_FAST}ms"
else
    echo "  SKIP: No wallpapers found"
fi
echo ""

# Test 6: Color extraction time
echo "[Test 6] Wallust color extraction (thumb backend)"
if [ -n "$RANDOMPICS" ] && [ -f "$RANDOMPICS" ]; then
    START=$(date +%s%N)
    wallust run "$RANDOMPICS" -s > /dev/null 2>&1
    END=$(date +%s%N)
    WALLUST_TIME=$(( (END - START) / 1000000 ))
    echo "  Result: ${WALLUST_TIME}ms"
else
    echo "  SKIP: No wallpapers found"
    WALLUST_TIME=0
fi
echo ""

# Test 7: Color file copy time (pre-cached colors)
echo "[Test 7] Pre-cached color file copy"
if [ -f "$HOME/.config/waybar/wallust/colors-waybar.css" ]; then
    START=$(date +%s%N)
    cp "$HOME/.config/waybar/wallust/colors-waybar.css" "$CACHE_DIR/benchmark_colors.css" 2>/dev/null
    END=$(date +%s%N)
    COPY_TIME=$(( (END - START) / 1000000 ))
    echo "  Result: ${COPY_TIME}ms"
    rm "$CACHE_DIR/benchmark_colors.css" 2>/dev/null
else
    echo "  SKIP: No color file found"
    COPY_TIME=0
fi
echo ""

# Summary
echo "====================================="
echo "SUMMARY"
echo "====================================="
echo ""
echo "Cold start (1st wallpaper change):"
echo "  Script startup:       ${STARTUP_TIME}ms"
echo "  Random selection:     ${RANDOM_TIME}ms"
echo "  swww command:         $((SWWW_TIME - 300))ms"
echo "  Fade animation:       300ms"
echo "  --------------------------------"
echo "  TOTAL (until visible): $((STARTUP_TIME + RANDOM_TIME + SWWW_TIME))ms"
echo ""
echo "Hot path (2nd+ wallpaper change):"
echo "  Script startup:       ${STARTUP_TIME}ms"
echo "  Cache read:           ${READ_TIME}ms"
echo "  swww command:         $((SWWW_TIME - 300))ms"
echo "  Fade animation:       300ms"
echo "  --------------------------------"
echo "  TOTAL (until visible): $((STARTUP_TIME + READ_TIME + SWWW_TIME))ms"
echo ""
echo "Background operations (don't block wallpaper):"
echo "  Color extraction:     ${WALLUST_TIME}ms"
echo "  Color file copy:      ${COPY_TIME}ms"
echo ""
echo "====================================="
echo ""
echo "Interpretation:"
echo "- Wallpaper becomes visible after fade animation completes"
echo "- Hot path is ${READ_TIME}ms faster than cold start"
echo "- Colors update ${WALLUST_TIME}ms after wallpaper (if not cached)"
echo "- With cached colors, total experience: $((STARTUP_TIME + READ_TIME + SWWW_TIME + COPY_TIME))ms"
echo ""
