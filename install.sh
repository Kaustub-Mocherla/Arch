#!/bin/bash
# THERMAL-SAFE End-4 Installation (No AGS compilation)

echo "🌡️ THERMAL-SAFE END-4 INSTALLER (Skipping AGS compilation)"

# Step 1: Cool down period
echo "⏸️  Mandatory 60-second cooling period..."
sleep 60

# Step 2: Backup current setup
BACKUP_DIR="$HOME/.config-working-backup-$(date +%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ~/.config/hypr ~/.config/waybar "$BACKUP_DIR/" 2>/dev/null || true
echo "$BACKUP_DIR" > ~/.working-backup-location
echo "✅ Backup created: $BACKUP_DIR"

# Step 3: Download End-4 (no compilation)
mkdir -p ~/files
cd ~/files
rm -rf dots-hyprland 2>/dev/null || true
git clone --depth=1 https://github.com/end-4/dots-hyprland.git
cd dots-hyprland
echo "✅ End-4 downloaded"

# Cool down
echo "🌡️ Cooling break (30s)..."
sleep 30

# Step 4: Install configs ONLY (no compilation)
echo "📁 Installing End-4 configurations (no compilation)..."

# Install Hyprland configs
if [ -d ".config/hypr" ]; then
    cp -r .config/hypr ~/.config/
    echo "✅ Hyprland configs installed"
fi
sleep 20

# Install Waybar configs (skip AGS)
if [ -d ".config/waybar" ]; then
    cp -r .config/waybar ~/.config/
    echo "✅ Waybar configs installed"
fi
sleep 20

# Install other configs
cp -r .config/kitty ~/.config/ 2>/dev/null || true
cp -r .config/wofi ~/.config/ 2>/dev/null || true
cp -r .config/gtk-3.0 ~/.config/ 2>/dev/null || true
cp -r .config/gtk-4.0 ~/.config/ 2>/dev/null || true
sleep 15

# Install themes and icons
if [ -d ".local" ]; then
    mkdir -p ~/.local
    cp -r .local/* ~/.local/ 2>/dev/null || true
    echo "✅ Themes installed"
fi
sleep 15

# Final configs (excluding AGS)
find .config -maxdepth 1 -type d ! -name "ags" -exec cp -r {} ~/.config/ \; 2>/dev/null || true

echo "🎉 End-4 installed WITHOUT AGS (no thermal stress)"
echo "🔄 Restart Hyprland: Super + M"

# Create AGS installer for later (when system is cool)
cat > ~/install-ags-later.sh << 'EOF'
#!/bin/bash
echo "🌡️ Installing AGS when system is cool..."
echo "⚠️  This will take time and generate heat"
read -p "CPU temperature should be <60°C. Continue? (y/N): " -n 1 -r
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# Limit CPU usage for AGS compilation
export MAKEFLAGS="-j1"  # Use only 1 core
nice -n 19 yay -S --needed --noconfirm ags

echo "✅ AGS installed with thermal protection"
EOF

chmod +x ~/install-ags-later.sh

echo "💡 To install AGS later (when cool): ~/install-ags-later.sh"
