# First, get back to your home directory
cd ~

# Create and run the desktop fix script
cat > ~/fix-desktop-now.sh << 'EOF'
#!/bin/bash
echo "🔧 Emergency Desktop Fix"

# Kill any stuck processes
killall waybar swww hyprpaper 2>/dev/null || true
sleep 3

# Install waybar if missing
sudo pacman -S --needed --noconfirm waybar hyprpaper

# Create basic waybar config
mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'WAYBAR'
{
    "layer": "top",
    "position": "top", 
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery"],
    
    "hyprland/workspaces": {
        "format": "{id}"
    },
    "clock": {
        "format": "{:%H:%M}"
    },
    "battery": {
        "format": "{capacity}%",
        "states": {
            "warning": 30,
            "critical": 15
        }
    }
}
WAYBAR

# Create wallpaper config
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprpaper.conf << 'PAPER'
preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
PAPER

# Start desktop components
echo "Starting waybar..."
waybar &
sleep 2

echo "Starting wallpaper..."
hyprpaper &
sleep 2

echo "✅ Desktop should now be visible!"
EOF

chmod +x ~/fix-desktop-now.sh
./fix-desktop-now.sh
