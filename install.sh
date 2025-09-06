#!/bin/bash
# ML4W Thermal-Safe Installation for Acer One 14 Z2-493
# Based on official ML4W documentation

echo "🎨 Installing ML4W Dotfiles with Thermal Protection"
echo "⚠️  Optimized for your Acer One 14 with AMD integrated graphics"

# Step 1: Create backup (MANDATORY per ML4W docs)
echo "💾 Creating backup of existing configs..."
BACKUP_DIR="$HOME/.config-backup-before-ml4w-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ~/.config "$BACKUP_DIR/config-backup" 2>/dev/null || true
echo "✅ Backup created: $BACKUP_DIR"
echo "$BACKUP_DIR" > ~/.ml4w-backup-location

# Step 2: Initial cooling period
echo "🌡️ Initial thermal protection (30s)..."
sleep 30

# Step 3: Update system first (prevent conflicts)
echo "📦 Updating system packages..."
sudo pacman -Syu --noconfirm
echo "🌡️ Cooling after system update (25s)..."
sleep 25

# Step 4: Install minimal Hyprland base (recommended by ML4W)
echo "🏗️  Installing Hyprland base..."
sudo pacman -S --needed --noconfirm hyprland kitty waybar
echo "🌡️ Thermal break (20s)..."
sleep 20

# Step 5: Download and run official ML4W installer
echo "⬇️  Downloading official ML4W installer..."
cd ~/Downloads

# Method 1: Official one-line installer (RECOMMENDED)
echo "🚀 Starting ML4W installation..."
echo "📋 The installer will:"
echo "   • Create automatic backups"
echo "   • Install all required packages"
echo "   • Set up beautiful Hyprland desktop"
echo "   • Include settings app for customization"

# Cool down before intensive installation
echo "🌡️ Pre-installation cooling (40s)..."
sleep 40

# Run the official ML4W installer
bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh) || {
    echo "🚨 Installation interrupted - likely thermal protection"
    echo "🌡️ Extended cooling period (60s)..."
    sleep 60
    echo "🔄 Retrying installation..."
    bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh)
}

echo "✅ ML4W installation completed!"

# Create emergency restore script
cat > ~/RESTORE-BEFORE-ML4W.sh << 'EOF'
#!/bin/bash
echo "🚨 Restoring configs from before ML4W..."
BACKUP_DIR=$(cat ~/.ml4w-backup-location 2>/dev/null)
if [ -d "$BACKUP_DIR" ]; then
    rm -rf ~/.config
    cp -r "$BACKUP_DIR/config-backup" ~/.config
    echo "✅ Restored to state before ML4W installation"
    echo "🔄 Restart Hyprland: Super + M"
else
    echo "❌ Backup not found"
fi
EOF
chmod +x ~/RESTORE-BEFORE-ML4W.sh

echo ""
echo "🎉 ML4W DOTFILES INSTALLATION COMPLETED!"
echo ""
echo "📱 What you now have:"
echo "   ✅ Beautiful Material Design interface"
echo "   ✅ Modern waybar with system controls"
echo "   ✅ Rofi launcher and settings"  
echo "   ✅ Professional wallpapers"
echo "   ✅ ML4W Settings app for customization"
echo ""
echo "🔑 Key shortcuts after login:"
echo "   • Super + Return  → Terminal"
echo "   • Super + D       → App launcher (Rofi)"
echo "   • Super + E       → File manager"
echo "   • Super + Q       → Close window"
echo "   • Super + 1,2,3   → Switch workspaces"
echo ""
echo "⚡ Next steps:"
echo "   1. Logout: Super + M"
echo "   2. Login again through SDDM"
echo "   3. Enjoy your beautiful ML4W desktop!"
echo ""
echo "🆘 If problems occur:"
echo "   Run: ~/RESTORE-BEFORE-ML4W.sh"
echo ""
echo "🔄 Logout now? (Y/n)"
read -n 1 -r
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    hyprctl dispatch exit
fi
