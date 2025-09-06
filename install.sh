cat > ~/fix-desktop.sh << 'EOF'
#!/bin/bash
echo "🔧 Fixing Hyprland Desktop Components"

# Kill problematic processes
killall waybar swww hyprpaper 2>/dev/null || true
sleep 2

# Create basic waybar config if missing
mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery", "network"],
    
    "hyprland/workspaces": {
        "format": "{id}"
    },
    "clock": {
        "format": "{:%H:%M}"
    },
    "battery": {
        "format": "{capacity}% {icon}",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi": "{essid}",
        "format-disconnected": "Disconnected"
    }
}
WAYBAR

# Create basic hyprpaper config
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprpaper.conf << 'PAPER'
preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
ipc = on
PAPER

# Start components
echo "Starting waybar..."
waybar &
sleep 2

echo "Starting wallpaper..."
hyprpaper &

echo "✅ Desktop components started!"
echo "You should now see waybar at top and wallpaper"
EOF

chmod +x ~/fix-desktop.sh
./fix-desktop.sh
