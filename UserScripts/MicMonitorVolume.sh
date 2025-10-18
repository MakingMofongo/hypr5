#!/bin/bash
# Adjust microphone monitoring volume

# Sony PlayStation Eye source device name
MIC_SOURCE="alsa_input.usb-OmniVision_Technologies__Inc._USB_Camera-B4.09.24.1-01.analog-surround-40"

# Get the device ID dynamically
MIC_ID=$(wpctl status | grep -A 100 "Sources:" | grep "Sony Playstation Eye" | sed 's/[^0-9]*\([0-9]\+\).*/\1/' | head -1)

if [ -z "$MIC_ID" ]; then
    notify-send -t 2000 "Mic Monitor" "Mic device not found" -i audio-input-microphone
    exit 1
fi

# Get current volume
CURRENT_VOL=$(wpctl get-volume "$MIC_ID" | awk '{print $2}')

case "$1" in
    up)
        wpctl set-volume "$MIC_ID" 10%+
        NEW_VOL=$(wpctl get-volume "$MIC_ID" | awk '{print int($2 * 100)}')
        notify-send -t 1500 "Mic Monitor Volume" "${NEW_VOL}%" -i audio-input-microphone
        ;;
    down)
        wpctl set-volume "$MIC_ID" 10%-
        NEW_VOL=$(wpctl get-volume "$MIC_ID" | awk '{print int($2 * 100)}')
        notify-send -t 1500 "Mic Monitor Volume" "${NEW_VOL}%" -i audio-input-microphone
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac
