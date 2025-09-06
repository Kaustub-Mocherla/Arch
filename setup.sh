# Reload Hyprland configuration
hyprctl reload

# Or restart waybar if it's not showing properly
killall waybar
waybar &

# Start wallpaper
killall hyprpaper 2>/dev/null
hyprpaper &
