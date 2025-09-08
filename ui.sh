#!/bin/bash

# Single script to fix missing nmtui and network connection issues in ML4W Hyprland

# Update system
sudo pacman -Syu --noconfirm

# Install NetworkManager (includes nmcli and nmtui)
sudo pacman -S --noconfirm networkmanager

# Enable and start NetworkManager
sudo systemctl enable --now NetworkManager

# Stop and disable conflicting network services
sudo systemctl stop dhcpcd wpa_supplicant systemd-networkd
sudo systemctl disable dhcpcd wpa_supplicant systemd-networkd

# Remove nm-applet to prevent GTK conflicts
sudo pacman -Rns --noconfirm network-manager-applet

# Kill existing nm-applet and waybar processes
killall nm-applet waybar 2>/dev/null

# Start waybar
nohup waybar &>/dev/null &

# Notify user
echo "NetworkManager setup done. 'nmtui' should now be available."
echo "Please reboot for full effect."
