# Add waybar back
echo "exec-once = waybar" >> ~/.config/hypr/hyprland.conf
hyprctl reload

# If waybar works, add wallpaper
echo "exec-once = hyprpaper" >> ~/.config/hypr/hyprland.conf
# Create basic wallpaper config
mkdir -p ~/.config/hypr
echo "preload = /usr/share/pixmaps/archlinux-logo.png" > ~/.config/hypr/hyprpaper.conf
echo "wallpaper = ,/usr/share/pixmaps/archlinux-logo.png" >> ~/.config/hypr/hyprpaper.conf
hyprctl reload
