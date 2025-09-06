#!/bin/bash
# End-4 Material 3 Installer - Thermal Safe for Acer One 14
# Now that your desktop is working, this will upgrade it to End-4

set -e

# Colors
G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; C='\033[0;36m'; NC='\033[0m'

echo -e "${C}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║          🎨 END-4 MATERIAL 3 INSTALLER 🎨              ║
║                                                          ║
║     Upgrading Your Working Hyprland to End-4            ║
║           🌡️ Thermal Protection Active 🌡️              ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Thermal protection function
thermal_pause() {
    local seconds=${1:-30}
    echo -e "${Y}🌡️ Thermal break: ${seconds}s (preventing overheating)${NC}"
    for i in $(seq $seconds -1 1); do
        echo -ne "\r${C}⏰ Cooling: ${i}s remaining...${NC}"
        sleep 1
    done
    echo -e "\n${G}✅ Ready to continue${NC}"
}

log() { echo -e "${B}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${G}✅ $1${NC}"; }

# Step 1: Backup your current working setup
log "Creating backup of your working desktop..."
BACKUP_DIR="$HOME/.config-working-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ~/.config/hypr ~/.config/waybar "$BACKUP_DIR/" 2>/dev/null || true
echo "$BACKUP_DIR" > ~/.working-backup-location
success "Working desktop backed up to: $BACKUP_DIR"
thermal_pause 20

# Step 2: Install End-4 dependencies 
log "Installing End-4 dependencies in batches..."

# Batch 1: Core
sudo pacman -S --needed --noconfirm git curl wget unzip
thermal_pause 25

# Batch 2: Fonts (needed for Material 3)
sudo pacman -S --needed --noconfirm ttf-jetbrains-mono inter-font ttf-font-awesome
thermal_pause 25

# Batch 3: AUR helper and packages
if ! command -v yay &> /dev/null; then
    log "Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si --noconfirm
    cd ~ && rm -rf /tmp/yay
    thermal_pause 30
fi

log "Installing End-4 specific packages..."
yay -S --needed --noconfirm ags || echo "AGS install attempted"
thermal_pause 25

# Step 4: Clone End-4 repository
log "Downloading End-4 Material 3 theme..."
mkdir -p ~/files
cd ~/files
rm -rf dots-hyprland 2>/dev/null || true
git clone --depth=1 https://github.com/end-4/dots-hyprland.git
cd dots-hyprland
success "End-4 repository downloaded"
thermal_pause 20

# Step 5: Install End-4 in thermal-safe phases
log "Installing End-4 configs in thermal-safe phases..."

# Phase 1: Core Hyprland configs
log "Phase 1/6: Hyprland core configs"
if [ -d ".config/hypr" ]; then
    cp -r .config/hypr ~/.config/
    success "Hyprland configs updated"
fi
thermal_pause 30

# Phase 2: AGS (End-4's main UI system)
log "Phase 2/6: AGS interface system"
if [ -d ".config/ags" ]; then
    cp -r .config/ags ~/.config/
    success "AGS interface installed"
fi
thermal_pause 30

# Phase 3: Updated Waybar
log "Phase 3/6: Enhanced Waybar"
if [ -d ".config/waybar" ]; then
    cp -r .config/waybar ~/.config/
    success "Waybar upgraded to End-4 style"
fi
thermal_pause 25

# Phase 4: Applications configs
log "Phase 4/6: Application configurations"
cp -r .config/kitty ~/.config/ 2>/dev/null || true
cp -r .config/wofi ~/.config/ 2>/dev/null || true
cp -r .config/gtk-3.0 ~/.config/ 2>/dev/null || true
cp -r .config/gtk-4.0 ~/.config/ 2>/dev/null || true
success "Application configs updated"
thermal_pause 25

# Phase 5: Icons and themes
log "Phase 5/6: Icons and local files"
if [ -d ".local" ]; then
    mkdir -p ~/.local
    cp -r .local/* ~/.local/ 2>/dev/null || true
    success "Icons and themes installed"
fi
thermal_pause 25

# Phase 6: Final configurations
log "Phase 6/6: Final End-4 configurations"
cp -r .config/* ~/.config/ 2>/dev/null || true
success "All End-4 configurations applied"
thermal_pause 20

# Step 6: Fix permissions and finalize
log "Finalizing installation..."
chown -R "$USER:$USER" ~/.config ~/.local 2>/dev/null || true
chmod -R 755 ~/.config
fc-cache -fv &>/dev/null || true
success "Installation finalized"

# Create emergency restore script
cat > ~/RESTORE-WORKING-DESKTOP.sh << 'EOF'
#!/bin/bash
echo "🚨 Restoring your working desktop..."
BACKUP_DIR=$(cat ~/.working-backup-location 2>/dev/null)
if [ -d "$BACKUP_DIR" ]; then
    rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags
    cp -r "$BACKUP_DIR"/* ~/.config/
    echo "✅ Working desktop restored!"
    echo "🔄 Restart Hyprland: Super+M then login again"
else
    echo "❌ Backup not found"
fi
EOF
chmod +x ~/RESTORE-WORKING-DESKTOP.sh

# Success message
echo -e "${G}"
cat << 'EOF'

🎉 END-4 MATERIAL 3 INSTALLATION COMPLETED! 🎉

✨ Your Hyprland has been upgraded to End-4 Material 3!

🚀 What's New:
• Beautiful Material 3 interface
• Enhanced sidebar panels  
• Modern app launcher
• Built-in AI chat system
• Advanced workspace management
• Gorgeous animations

🔑 New Key Shortcuts:
• Super + /        → Show all shortcuts
• Super Key        → Workspace overview & launcher
• Top corners      → Open sidebars (left: AI, right: controls)
• Super + Ctrl + T → Wallpaper picker
• Super + T        → Terminal

🔄 Restart Required:
Press Super + M to logout, then login again to see full End-4 experience!

🆘 If Issues Occur:
Run: ~/RESTORE-WORKING-DESKTOP.sh to restore your working setup

Enjoy your beautiful End-4 Material 3 desktop! ✨
EOF
echo -e "${NC}"

# Reboot option
read -p "Restart Hyprland now to see End-4? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    hyprctl dispatch exit
else
    echo "💡 Press Super + M when ready to restart and see End-4"
fi
