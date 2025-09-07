#!/bin/bash

# Update system packages
sudo pacman -Syu --noconfirm

# Install required network manager packages
sudo pacman -S --needed networkmanager network-manager-applet nm-connection-editor --noconfirm

# Enable and start NetworkManager
sudo systemctl enable --now NetworkManager

# Kill existing nm-applet and waybar processes if any
killall nm-applet waybar 2>/dev/null

# Start nm-applet with indicator
nm-applet --indicator &

# Restart waybar
waybar &

# Notify user
echo "Network manager applet and waybar restarted. Click the network icon to see popup."
