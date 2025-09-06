#!/bin/bash
# Fix ML4W Config Error - Update to Compatible Version

echo "🛠️ Fixing ML4W config error..."

# Step 1: Update ML4W to latest version (fixes the decoration error)
echo "📦 Updating ML4W to latest version..."
yay -S --noconfirm ml4w-hyprland-dotfiles
sleep 15

# Step 2: Run ML4W setup to fix configs
echo "🔧 Running ML4W setup to fix configuration..."
ml4w-hyprland-setup

# Step 3: Alternative fix - Manual config update
echo "🔨 Applying manual config fix..."
cd ~/.config/hypr/conf/decorations/
cp default.conf default.conf.backup

# Download the fixed decoration config
curl -s -o default.conf https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/share/dotfiles/.config/hypr/conf/decorations/default.conf

echo "✅ ML4W configuration fixed!"
echo "🔄 Reloading Hyprland..."
hyprctl reload

echo "🎉 ML4W should now work properly!"
