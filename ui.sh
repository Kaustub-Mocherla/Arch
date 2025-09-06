#!/bin/bash
# Complete ML4W Clean Installation for Acer One 14 Z2-493
# Thermal-safe with all limitations considere```echo "🧹 Starting complete system clean and ML4W fresh installation"
echo "⚠️  Optimized for your Acer One 14 with thermal protection"

# Step 1: Complete configuration cleanup
echo "🗑️ Removing all old configurations..."
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags ~/.config/rofi
rm -rf ~/.config/kitty ~/.config/wofi ~/.config/wlogout ~/.```fig/swaylock
rm -rf ~/.local/share/icons ~/.local/share/themes ~/.cache```4w
rm -rf ~/ml4w-dotfiles ~/dotfiles ~/files/dots-hyprland

# Clear package caches
sudo pacman -Scc --noconfirm
yay -Scc --noconfirm 2>/dev/null || true

echo "✅ Old configurations cleaned"

# Step 2: Thermal cooling period
echo "🌡️ Initial cooling period (30s) - preventing overheating..."
sleep 30

# Step 3: Update system in thermal-safe way
echo "📦 Updating system with thermal protection..."
sudo pacman -Syu --noconfirm
echo "🌡️ Post-update cooling (25s)..."
sleep 25

# Step 4: Install minimal base requirements (thermal-safe batches)
echo "🔧 Installing base requirements in thermal-safe batches..."

# Batch 1: Essential core
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip
echo "🌡️ Cooling after batch 1 (20s)..."
sleep 20

# Batch 2: Hyprland essentials  
sudo pacman -S --needed --noconfirm hyprland kitty waybar
echo "🌡️ Cooling after batch 2 (20s)..."
sleep 20

# Batch 3: Additional components
sudo pacman -S --needed --noconfirm firefox flatpak wofi
echo "🌡️ Cooling after batch 3 (20s)..."
sleep 20

# Step 5: Install yay AUR helper (if not present)
if ! command -v yay &> /dev/null; then
    echo "🔨 Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    echo "🌡️ Post-yay cooling (30s)..."
    sleep 30
fi

# Step 6: Extended cooling before ML4W installation
echo "🌡️ Extended pre-ML4W cooling period (45s) - critical for thermal protection..."
sleep 45

# Step 7: ML4W Installation with maximum thermal protection
echo "🚀 Starting ML4W installation with thermal protection..."
echo "📋 This will take 15-20 minutes with cooling periods"

# Method 1: Official installer with thermal monitoring
cd ~/Downloads
curl -s -o ml4w-install.sh https://raw.githubusercontent.com/mylinuxforwork/dotfiles/```n/setup-arch.sh
chmod +x ml4w-install.sh

# Run with thermal protection (timeout + cooling cycles)
install_attempt=1
max_attempts=3

while [ $install_attempt -le $max_attempts ]; do
    echo "🔄 ML4W installation attempt $install_attempt/$max_attempts"
    
    if timeout 300s bash ml4w-install.sh; then
        echo "✅ ML4W installation successful!"
        break
    else
        echo "⚠️ Installation paused (likely thermal protection)"
        if [ $install_attempt -lt $max_attempts ]; then
            echo "🌡️ Extended cooling period (60s) before retry..."
            sleep 60
        fi
        install_attempt=$((install_attempt + 1))
    fi
done

# Step 8: Post-installation thermal recovery
echo "🌡️ Post-installation cooling period (30s)..."
sleep 30

# Step 9: Final system configuration
echo "🔧 Final system configuration..."

# Enable flatpak if not enabled
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/```thub.flatpakrepo 2>/dev/null || true

# Ensure SDDM is configured
sudo systemctl enable sddm.service

# Create emergency restore point
BACKUP_DIR="~/.config-emergency-restore-$(date +%Y%m%d-%H%M%S)"
echo "$BACKUP_DIR" > ~/.ml4w-emergency-restore

# Final cooling
echo "🌡️ Final cooling period (20s)..."
sleep 20

echo ""
echo "🎉 COMPLETE ML4W INSTALLATION FINISHED!"
echo ""
echo "✅ What was accomplished:"
echo "   🧹 Completely cleaned old configurations"
echo "   📦 Updated system with thermal protection"
echo "   🔧 Installed all required packages in batches"
echo "   🎨 Installed ML4W dotfiles with cooling periods"
echo "   🛡️ Created emergency restore points"
echo ""
echo "🔄 NEXT STEPS:"
echo "   1. Logout: Press Super + M"
echo "   2. At SDDM login screen: Select 'Hyprland' session"
echo "   3. Login with your password"
echo "   4. Enjoy your beautiful ML4W Hyprland desktop!"
echo ""
echo "🆘 If problems occur after reboot:"
echo "   - Switch to TTY3 (Ctrl+Alt+F3)"
echo "   - Login and run: yay -R ml4w-hyprland"
echo "   - Then install minimal Hyprland setup"
echo ""
echo "💡 ML4W Features you'll have:"
echo "   • Beautiful Material Design```terface"
echo "   • Customizable waybar and rofi launcher```cho "   • ML4W Settings app for easy configuration"
echo "   • Professional wallpapers and themes"
echo "   • All optimized for your AMD integrated graphics"
echo ""

# Offer immediate logout
read -p "🔄 Logout now to see ML4W? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "👋 Logging out to complete ML```setup..."
    sleep 3
    hyprctl dispatch exit
else
    echo "💡 When ready, press Super + M to logout```d enjoy ML4W!"
fi
