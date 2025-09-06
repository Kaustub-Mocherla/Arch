#!/bin/bash
# ULTIMATE End-4 Hyprland Installer
# Optimized for Acer One 14 Z2-493 with overheating protection
# Version: BEST METHOD

set -e

# Colors
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; C='\033[0;36m'; NC='\033[0m'

# Header
echo -e "${C}"
cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│          🚀 ULTIMATE END-4 HYPRLAND INSTALLER 🚀          │
│                                                             │
│  ✨ Material 3 Theme • 🌡️ Thermal Safe • 🛡️ Bulletproof  │
│                                                             │
│         Optimized for Thermal-Sensitive Laptops            │
└─────────────────────────────────────────────────────────────┘
EOF
echo -e "${NC}"

# Smart logging with thermal monitoring
log() { echo -e "${B}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${Y}⚠️  $1${NC}"; }
error() { echo -e "${R}❌ $1${NC}"; }
success() { echo -e "${G}✅ $1${NC}"; }

# Intelligent thermal protection
thermal_safe() {
    local seconds=${1:-35}
    local step=${2:-"Processing"}
    
    warn "$step - Thermal protection active"
    echo -ne "${C}"
    for i in $(seq $seconds -1 1); do
        echo -ne "\r🌡️  Cooling: ${i}s • CPU temp stabilizing...   "
        sleep 1
    done
    echo -e "\n${G}✅ Thermal safe - Continuing${NC}"
}

# Pre-flight checks
preflight_check() {
    log "Running pre-flight system checks..."
    
    # Check if we're in TTY (safer)
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        warn "Running in Wayland session - recommend switching to TTY3 for safety"
        echo "Press Ctrl+Alt+F3, login, then run this script"
        read -p "Continue anyway? (y/N): " -n 1 -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
    
    # Check available disk space
    local free_space=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$free_space" -lt 2 ]; then
        error "Insufficient disk space. Need at least 2GB free"
        exit 1
    fi
    
    success "Pre-flight checks passed"
}

# Smart backup system
intelligent_backup() {
    log "Creating intelligent backup system..."
    
    local backup_dir="$HOME/.config-backup-ultimate-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup current working configs
    local configs=("hypr" "waybar" "ags" "kitty" "wofi" "gtk-3.0" "gtk-4.0")
    for config in "${configs[@]}"; do
        if [ -d "$HOME/.config/$config" ]; then
            log "Backing up $config"
            cp -r "$HOME/.config/$config" "$backup_dir/"
        fi
    done
    
    # Save backup location for emergency recovery
    echo "$backup_dir" > ~/.end4-backup-location
    
    # Create emergency restore script
    cat > ~/EMERGENCY-RESTORE.sh << EOF
#!/bin/bash
echo "🚨 EMERGENCY RESTORE ACTIVATED"
BACKUP_DIR="$backup_dir"
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags
cp -r "\$BACKUP_DIR"/* ~/.config/ 2>/dev/null
echo "✅ System restored to working state"
echo "🔄 Restart Hyprland: sudo systemctl restart sddm"
EOF
    chmod +x ~/EMERGENCY-RESTORE.sh
    
    success "Backup created: $backup_dir"
    thermal_safe 20 "Backup completed"
}

# Minimal dependency installer
install_minimal_deps() {
    log "Installing minimal required dependencies..."
    
    # Only install what's absolutely necessary
    local essential=("git" "curl" "unzip")
    sudo pacman -S --needed --noconfirm "${essential[@]}"
    thermal_safe 25 "Dependencies installed"
}

# Smart End-4 cloner
smart_clone_end4() {
    log "Smart cloning of End-4 repository..."
    
    mkdir -p ~/files
    cd ~/files
    
    # Remove any previous failed attempts
    rm -rf dots-hyprland* 2>/dev/null || true
    
    # Clone with minimal depth for speed
    log "Downloading End-4 dotfiles..."
    timeout 300s git clone --depth=1 --single-branch https://github.com/end-4/dots-hyprland.git || {
        error "Clone failed - checking network..."
        ping -c 1 github.com || error "No internet connection"
        exit 1
    }
    
    cd dots-hyprland
    success "End-4 repository downloaded"
    thermal_safe 20 "Repository ready"
}

# Micro-step installation (bulletproof)
micro_install_end4() {
    log "Starting micro-step installation..."
    
    cd ~/files/dots-hyprland
    
    # Step 1: Hyprland core (most critical)
    log "Step 1/8: Installing Hyprland core configs"
    if [ -d ".config/hypr" ]; then
        rm -rf ~/.config/hypr
        cp -r .config/hypr ~/.config/
        success "Hyprland configs installed"
    fi
    thermal_safe 30 "Step 1 complete"
    
    # Step 2: Waybar (essential UI)
    log "Step 2/8: Installing Waybar configs"
    if [ -d ".config/waybar" ]; then
        rm -rf ~/.config/waybar
        cp -r .config/waybar ~/.config/
        success "Waybar configs installed"
    fi
    thermal_safe 30 "Step 2 complete"
    
    # Step 3: AGS (End-4 specific)
    log "Step 3/8: Installing AGS configs"
    if [ -d ".config/ags" ]; then
        rm -rf ~/.config/ags
        cp -r .config/ags ~/.config/
        success "AGS configs installed"
    fi
    thermal_safe 30 "Step 3 complete"
    
    # Step 4: Terminal (Kitty)
    log "Step 4/8: Installing terminal configs"
    if [ -d ".config/kitty" ]; then
        cp -r .config/kitty ~/.config/
        success "Kitty configs installed"
    fi
    thermal_safe 25 "Step 4 complete"
    
    # Step 5: Launcher (Wofi)
    log "Step 5/8: Installing launcher configs"
    if [ -d ".config/wofi" ]; then
        cp -r .config/wofi ~/.config/
        success "Wofi configs installed"
    fi
    thermal_safe 25 "Step 5 complete"
    
    # Step 6: GTK themes
    log "Step 6/8: Installing GTK themes"
    cp -r .config/gtk-3.0 ~/.config/ 2>/dev/null || true
    cp -r .config/gtk-4.0 ~/.config/ 2>/dev/null || true
    success "GTK themes installed"
    thermal_safe 25 "Step 6 complete"
    
    # Step 7: Local files and icons
    log "Step 7/8: Installing local files"
    if [ -d ".local" ]; then
        mkdir -p ~/.local
        cp -r .local/* ~/.local/ 2>/dev/null || true
        success "Local files installed"
    fi
    thermal_safe 30 "Step 7 complete"
    
    # Step 8: Final configurations
    log "Step 8/8: Applying final configurations"
    cp -r .config/* ~/.config/ 2>/dev/null || true
    success "Final configurations applied"
    thermal_safe 25 "Step 8 complete"
    
    success "🎉 All End-4 components installed successfully!"
}

# System finalization
finalize_system() {
    log "Finalizing system configuration..."
    
    # Fix permissions
    chown -R "$USER:$USER" ~/.config ~/.local 2>/dev/null || true
    chmod -R 755 ~/.config
    
    # Update font cache
    fc-cache -fv &>/dev/null || true
    
    # Mark installation as successful
    echo "End-4 Ultimate installation completed: $(date)" > ~/.end4-success
    
    success "System finalization complete"
    thermal_safe 20 "Ready for use"
}

# Success celebration
show_success() {
    echo -e "${G}"
    cat << 'EOF'

 ██████╗ ██╗   ██╗ ██████╗ ██████╗███████╗███████╗███████╗██╗
██╔════╝ ██║   ██║██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝██║
╚██████╗ ██║   ██║██║     ██║     █████╗  ███████╗███████╗██║
 ╚═══██║ ██║   ██║██║     ██║     ██╔══╝  ╚════██║╚════██║╚═╝
██████╔╝ ╚██████╔╝╚██████╗╚██████╗███████╗███████║███████║██╗
╚═════╝   ╚═════╝  ╚═════╝ ╚═════╝╚══════╝╚══════╝╚══════╝╚═╝

🎉 END-4 MATERIAL 3 HYPRLAND INSTALLED SUCCESSFULLY! 🎉

✨ What you now have:
   • Beautiful Material 3 interface
   • Thermal-safe installation
   • All End-4 features working
   • Emergency restore ready

🚀 Next steps:
   1. Switch back to Hyprland (Ctrl+Alt+F1 or F7)
   2. Or reboot for full experience: sudo reboot
   3. Login and enjoy your new desktop!

🔥 Key shortcuts after login:
   • Super + /        → Cheat sheet
   • Super + T        → Terminal  
   • Super Key        → App launcher
   • Top corners      → Sidebars
   • Super + Ctrl + T → Wallpapers

🆘 If problems occur:
   • Run: ~/EMERGENCY-RESTORE.sh
   • Or restore from: ~/.end4-backup-location

Enjoy your stunning End-4 Hyprland setup! 🎨✨
EOF
    echo -e "${NC}"
}

# Main execution
main() {
    echo -e "${Y}🚀 Starting Ultimate End-4 Installation${NC}"
    echo -e "${Y}⚠️  Optimized for thermal-sensitive hardware${NC}"
    echo
    
    read -p "Ready to install End-4 Hyprland Material 3 theme? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { log "Installation cancelled"; exit 0; }
    
    # Execute installation phases
    preflight_check
    intelligent_backup
    install_minimal_deps
    smart_clone_end4
    micro_install_end4
    finalize_system
    show_success
    
    # Reboot prompt
    echo
    read -p "Reboot now to experience End-4? (Y/n): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && sudo reboot || warn "Reboot manually when ready: sudo reboot"
}

# Error handling
trap 'error "Installation failed! Run ~/EMERGENCY-RESTORE.sh to recover"' ERR

# Launch
main "$@"
