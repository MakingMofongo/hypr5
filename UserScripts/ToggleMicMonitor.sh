#!/bin/bash
# Toggle microphone monitoring (loopback)

# Check if pw-loopback is running
if pgrep -x "pw-loopback" > /dev/null; then
    # Kill the loopback
    pkill pw-loopback
    notify-send -t 2000 "Mic Monitor" "Disabled" -i audio-input-microphone
else
    # Start high-quality loopback (48kHz, 32-bit, 4 channels)
    pw-loopback \
        --capture-props='audio.rate=48000 audio.format=S32LE audio.channels=4 node.target=alsa_input.usb-OmniVision_Technologies__Inc._USB_Camera-B4.09.24.1-01.analog-surround-40' \
        --playback-props='audio.rate=48000 audio.format=S32LE node.target=alsa_output.pci-0000_06_00.6.analog-stereo' &
    notify-send -t 2000 "Mic Monitor" "Enabled (48kHz/32-bit/4ch)" -i audio-input-microphone
fi
