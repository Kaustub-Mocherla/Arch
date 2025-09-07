#!/bin/bash

# Fix ML4W Hyprland WiFi popup with GTK error resolution
echo "Fixing ML4W WiFi popup and GTK errors..."

# Kill existing processes to avoid conflicts
killall nm-applet waybar 2>/dev/null
sleep 2

# Install/Update required packages
sudo pacman -S --needed networkmanager network-manager-applet nm-connection-editor waybar --noconfirm

# Enable NetworkManager service
sudo systemctl enable --now NetworkManager

# Set proper environment variables for GTK
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM=wayland;xcb

# Check if system tray is enabled in waybar config
WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
if [ -f "$WAYBAR_CONFIG" ]; then
    # Backup original config
    cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.backup"
    
    # Ensure tray module is enabled
    if ! grep -q '"tray"' "$WAYBAR_CONFIG"; then
        echo "Adding tray module to waybar config..."
        sed -i 's/"modules-right": \[/"modules-right": ["tray",/' "$WAYBAR_CONFIG"
    fi
fi

# Start nm-applet with proper options
echo "Starting NetworkManager applet..."
nm-applet --indicator --sm-disable &

# Wait a moment for nm-applet to initialize
sleep 3

# Restart waybar
echo "Restarting waybar..."
waybar &

# Wait for waybar to start
sleep 2

echo "WiFi popup fix applied. The GTK warnings should be reduced."
echo "Click on the network icon in the top bar to test."
