#!/bin/bash
# Complete ML4W Reset and Reinstall

echo "🔄 Complete ML4W reset and reinstall..."

# Remove old ML4W configs
rm -rf ~/.config/hypr
rm -rf ~/.config/waybar
rm -rf ~/.config/rofi

# Reinstall ML4W with latest version
yay -S --noconfirm ml4w-hyprland-dotfiles

# Run fresh setup
ml4w-hyprland-setup

echo "✅ Fresh ML4W installation complete!"
echo "🔄 Logout and login: Super + M"
