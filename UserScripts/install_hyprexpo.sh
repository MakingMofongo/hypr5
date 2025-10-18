#!/bin/bash

# HyprExpo Installation Script
# This script installs HyprExpo plugin for Hyprland

set -e

echo "=== HyprExpo Installation Script ==="
echo ""

# Check if hyprland-dev is installed
if ! dpkg -l | grep -q "ii  hyprland-dev"; then
    echo "Installing hyprland-dev package..."
    sudo apt-get update
    sudo apt-get install -y hyprland-dev
else
    echo "✓ hyprland-dev is already installed"
fi

# Update hyprpm
echo ""
echo "Updating hyprpm..."
hyprpm update

# Add official Hyprland plugins repository
echo ""
echo "Adding official Hyprland plugins repository..."
hyprpm add https://github.com/hyprwm/hyprland-plugins

# Enable HyprExpo
echo ""
echo "Enabling HyprExpo plugin..."
hyprpm enable hyprexpo

# Reload Hyprpm
echo ""
echo "Reloading plugins..."
hyprpm reload

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Add configuration to your hyprland.conf"
echo "2. Add keybindings to UserKeybinds.conf"
echo "3. Reload Hyprland with: hyprctl reload"
echo ""
echo "Or run: SUPER + ALT + R to refresh"
