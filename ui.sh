#!/bin/bash

# Setting up ML4W recommended NetworkManager TUI and removing conflicting network managers

# Stop and disable other conflicting services
sudo systemctl stop dhcpcd wpa_supplicant systemd-networkd
sudo systemctl disable dhcpcd wpa_supplicant systemd-networkd

# Enable and start NetworkManager
sudo systemctl enable --now NetworkManager

# Kill any existing nm-applet and waybar to prevent conflicts
killall nm-applet waybar 2>/dev/null

# Remove nm-applet since ML4W uses nmtui and conflicts can occur
sudo pacman -Rns --noconfirm network-manager-applet

# Restart waybar so it reflects changes correctly
waybar &

# Inform user
echo "Removed conflicting network managers and set up ML4W recommended NetworkManager TUI environment. Use 'nmtui' command to configure WiFi."
