mkdir -p ~/config_backups
mv ~/.config/hypr ~/config_backups/hypr_$(date +%F_%H%M%S) || true
mv ~/.config/waybar ~/config_backups/waybar_$(date +%F_%H%M%S) || true
mv ~/.config/hyprpaper ~/config_backups/hyprpaper_$(date +%F_%H%M%S) || true
mv ~/.config/wofi ~/config_backups/wofi_$(date +%F_%H%M%S) || true