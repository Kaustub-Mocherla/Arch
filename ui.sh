#!/bin/bash
# Complete MLW and Theme Removal Script

echo "🧹 Undoing all ML4W and theme changes..."

# Stop SDDM service
sudo systemctl stop sddm || true

# Remove all user configs and caches
rm -rf ~/.config
rm -rf ~/.cache  
rm -rf ~/.local/share

# Remove MLW installer scripts
rm -f ~/mlw-* ~/install-*

# Remove Waybar and Hyprland configs specifically
rm -rf ~/.config/waybar ~/.config/hypr ~/.config/hyprland

# Remove Sugar Candy theme
sudo rm -rf /usr/share/sddm/themes/sugar-candy* || true

# Reset SDDM configuration to default
sudo rm -f /etc/sddm.conf
sudo rm -rf /etc/sddm.conf.d/

# Reinstall SDDM to latest version
sudo pacman -S --noconfirm sddm

# Reinstall essential base packages
sudo pacman -S --noconfirm base base-devel

# Remove any AUR packages that might cause conflicts
yay -R sddm-sugar-candy-git sddm-theme-sugar-candy-git 2>/dev/null || true

# Enable and start SDDM with default configuration
sudo systemctl enable sddm.service
sudo systemctl start sddm.service

echo ""
echo "✅ Complete restoration finished!"
echo "🔄 Please reboot your system now: sudo reboot"
echo ""
echo "💡 After reboot, you'll have:"
echo "   • Clean SDDM login screen (default theme)"
echo "   • No ML4W configurations"
echo "   • Fresh system ready for new setup"
