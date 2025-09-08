#!/bin/bash

# Fix frequent WiFi disconnections in ML4W Hyprland

echo "Diagnosing WiFi disconnection issues..."

# Check for conflicting network services
echo "Checking running network services..."
systemctl list-units --type service | grep -E "(network|dhcp|wpa)"

# Stop and disable conflicting services
echo "Stopping conflicting network managers..."
sudo systemctl stop dhcpcd wpa_supplicant systemd-networkd
sudo systemctl disable dhcpcd wpa_supplicant systemd-networkd

# Enable only NetworkManager
sudo systemctl enable --now NetworkManager

# Disable WiFi power management (major cause of disconnects)
echo "Disabling WiFi power management..."
sudo mkdir -p /etc/NetworkManager/conf.d/
echo -e "[connection]\nwifi.powersave = 2" | sudo tee /etc/NetworkManager/conf.d/default-wifi-powersave-off.conf

# Restart NetworkManager to apply changes
sudo systemctl restart NetworkManager

# Fix nm-applet integration
killall nm-applet waybar 2>/dev/null
sleep 2
nm-applet --indicator &
waybar &

echo "WiFi disconnection fix applied!"
echo "Reboot recommended for full effect."
