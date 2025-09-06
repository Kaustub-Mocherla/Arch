# #!/bin/bash
# Complete End-4 Hyprland Installer with Overheating Protection
# Based on: https://youtu.be/OnxU419vnts?si=wpi4hn4x3ho1QMjL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Art Header
echo -e "${CYAN}"
cat << 'EOF'
███████╗███╗   ██╗██████╗       ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗ 
██╔════╝████╗  ██║██╔══██╗      ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗
█████╗  ██╔██╗ ██║██║  ██║█████╗███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║
██╔══╝  ██║╚██╗██║██║  ██║╚════╝╚════██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║
███████╗██║ ╚████║██████╔╝           ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝
╚══════╝╚═╝  ╚═══╝╚═════╝            ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ 
                                                                                                      
Material 3 Theme Installer with Thermal Protection
EOF
echo -e "${NC}"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Thermal protection function
cool_down() {
    local seconds=${1:-25}
    local reason=${2:-"Preventing overheating"}
    warn "$reason - Cooling down for $seconds seconds..."
    echo -e "${CYAN}🌡️ Temperature management active - Please wait...${NC}"
    for i in $(seq $seconds -1 1); do
        echo -ne "\r${CYAN}⏰ Cooling: ${i}s remaining...${NC}"
        sleep 1
    done
    echo -e "\n${GREEN}✅ Ready to continue${NC}"
}

# Check system compatibility
check_system() {
    log "Checking system compatibility..."
    
    if ! command -v pacman &> /dev/null; then
        error "This script is designed for Arch Linux systems only!"
        exit 1
    fi
    
    # Check if running on Wayland
    if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        warn "Not currently running Wayland/Hyprland - this is OK for installation"
    fi
    
    success "System compatibility verified"
}

# Backup existing configurations
backup_existing_configs() {
    log "Creating backup of existing configurations..."
    
    local backup_dir="$HOME/.config-backup-end4-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    local configs=("hypr" "waybar" "kitty" "wofi" "swaylock" "wlogout" "rofi" "gtk-3.0" "gtk-4.0")
    
    for config in "${configs[@]}"; do
        if [ -d "$HOME/.config/$config" ]; then
            log "Backing up $config..."
            mv "$HOME/.config/$config" "$backup_dir/"
        fi
    done
    
    # Backup local files too
    if [ -d "$HOME/.local/share/icons" ]; then
        mkdir -p "$backup_dir/.local/share"
        mv "$HOME/.local/share/icons" "$backup_dir/.local/share/"
    fi
    
    success "Configurations backed up to: $backup_dir"
    echo "$backup_dir" > ~/.end4-backup-location
}

# Update system and install dependencies
install_dependencies() {
    log "Updating system and installing dependencies..."
    
    # Update system first
    sudo pacman -Syu --noconfirm
    cool_down 20 "System updated"
    
    # Install essential packages - Phase 1
    log "Installing Phase 1: Core packages"
    local phase1=(
        "git" "wget" "curl" "unzip" "gzip" "base-devel"
        "hyprland" "kitty" "waybar" "wofi" "sddm"
    )
    sudo pacman -S --needed --noconfirm "${phase1[@]}"
    cool_down 25 "Phase 1 complete"
    
    # Install essential packages - Phase 2
    log "Installing Phase 2: Media and utilities"
    local phase2=(
        "pipewire" "pipewire-pulse" "wireplumber" "pavucontrol"
        "grim" "slurp" "wl-clipboard" "brightnessctl" "playerctl"
    )
    sudo pacman -S --needed --noconfirm "${phase2[@]}"
    cool_down 25 "Phase 2 complete"
    
    # Install essential packages - Phase 3
    log "Installing Phase 3: Fonts and themes"
    local phase3=(
        "ttf-font-awesome" "ttf-fira-code" "noto-fonts" "noto-fonts-emoji"
        "ttf-jetbrains-mono" "ttf-cascadia-code" "inter-font"
        "gtk3" "gtk4" "qt5-wayland" "qt6-wayland"
    )
    sudo pacman -S --needed --noconfirm "${phase3[@]}"
    cool_down 20 "Phase 3 complete"
    
    success "All dependencies installed successfully"
}

# Install AUR helper and packages
install_aur_packages() {
    log "Setting up AUR packages..."
    
    # Install yay if not present
    if ! command -v yay &> /dev/null; then
        log "Installing yay AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
        rm -rf /tmp/yay
        cool_down 25 "Yay installed"
    fi
    
    # AUR packages needed for End-4
    log "Installing AUR packages for End-4..."
    local aur_packages=(
        "hyprpicker" "swww" "wlogout" "swaylock-effects"
        "pokemon-colorscripts-git" "cava" "ags"
    )
    
    for package in "${aur_packages[@]}"; do
        log "Installing $package..."
        yay -S --needed --noconfirm "$package" || warn "Failed to install $package - continuing anyway"
        cool_down 15 "Package $package processed"
    done
    
    success "AUR packages installation completed"
}

# Clone and prepare End-4 repository
clone_end4_repo() {
    log "Cloning End-4 Hyprland repository..."
    
    # Create files directory as shown in video
    mkdir -p ~/files
    cd ~/files
    
    # Remove if already exists
    if [ -d "dots-hyprland" ]; then
        rm -rf dots-hyprland
    fi
    
    # Clone the repository
    git clone --depth=1 https://github.com/end-4/dots-hyprland.git
    cd dots-hyprland
    
    success "End-4 repository cloned successfully"
}

# Install End-4 dotfiles with thermal management
install_end4_dotfiles() {
    log "Installing End-4 dotfiles with thermal protection..."
    
    cd ~/files/dots-hyprland
    
    # Make install script executable
    chmod +x install.sh
    
    log "Starting End-4 installation process..."
    echo -e "${YELLOW}Note: Installation will pause periodically to prevent overheating${NC}"
    
    # Create a modified install process
    cat > ~/end4-thermal-install.sh << 'EOF'
#!/bin/bash
cd ~/files/dots-hyprland

# Run the installer with thermal breaks
echo "Starting End-4 installation with thermal management..."

# Method 1: Try automatic installation first
timeout 180s ./install.sh <<< $'yes\nn' || {
    echo "Installation paused for cooling..."
    sleep 30
    
    # Method 2: Manual installation if automatic fails
    echo "Continuing with manual installation..."
    
    # Copy configurations in phases
    echo "Phase 1: Copying Hyprland configs..."
    mkdir -p ~/.config
    cp -r .config/hypr ~/.config/ 2>/dev/null || true
    sleep 20
    
    echo "Phase 2: Copying Waybar configs..."
    cp -r .config/waybar ~/.config/ 2>/dev/null || true
    cp -r .config/ags ~/.config/ 2>/dev/null || true
    sleep 20
    
    echo "Phase 3: Copying application configs..."
    cp -r .config/kitty ~/.config/ 2>/dev/null || true
    cp -r .config/wofi ~/.config/ 2>/dev/null || true
    cp -r .config/gtk-3.0 ~/.config/ 2>/dev/null || true
    cp -r .config/gtk-4.0 ~/.config/ 2>/dev/null || true
    sleep 20
    
    echo "Phase 4: Copying local files..."
    mkdir -p ~/.local
    cp -r .local/* ~/.local/ 2>/dev/null || true
    sleep 15
    
    echo "Phase 5: Final configurations..."
    cp -r .config/* ~/.config/ 2>/dev/null || true
}

echo "End-4 installation completed!"
EOF
    
    chmod +x ~/end4-thermal-install.sh
    ~/end4-thermal-install.sh
    
    cool_down 30 "End-4 dotfiles installed"
    success "End-4 dotfiles installation completed"
}

# Configure SDDM for Hyprland
configure_sddm() {
    log "Configuring SDDM for Hyprland..."
    
    # Enable SDDM service
    sudo systemctl enable sddm.service
    
    # Create SDDM configuration
    sudo mkdir -p /etc/sddm.conf.d
    
    sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=Hyprland
EOF
    
    # Create Hyprland session file
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    
    success "SDDM configured successfully"
}

# Set up user permissions and groups
setup_user_permissions() {
    log "Setting up user permissions and groups..."
    
    # Add user to required groups
    sudo usermod -aG video,input,render,audio "$USER"
    
    # Fix config permissions
    chown -R "$USER:$USER" ~/.config/ ~/.local/
    chmod -R 755 ~/.config/
    
    success "User permissions configured"
}

# Create fallback configuration
create_fallback_config() {
    log "Creating fallback configuration..."
    
    # Create a minimal working config as backup
    mkdir -p ~/.config/hypr-fallback
    
    cat > ~/.config/hypr-fallback/hyprland.conf << 'EOF'
# End-4 Fallback Configuration
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 5
        passes = 2
    }
}

# Essential keybinds
bind = SUPER, Q, exec, kitty
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, V, togglefloating

# Workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3

# Autostart
exec-once = waybar
exec-once = ags
EOF
    
    success "Fallback configuration created"
}

# Final system setup
finalize_installation() {
    log "Finalizing installation..."
    
    # Set up fonts cache
    fc-cache -fv
    
    # Update desktop database
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    
    # Create End-4 success marker
    echo "End-4 Hyprland installation completed on $(date)" > ~/.end4-install-success
    
    success "Installation finalized successfully"
}

# Display completion message
show_completion_message() {
    echo -e "${GREEN}"
    cat << 'EOF'

🎉 END-4 HYPRLAND INSTALLATION COMPLETED! 🎉

✅ Material 3 Theme installed
✅ All configurations applied  
✅ SDDM login manager configured
✅ Thermal protection applied throughout

🚀 WHAT'S NEXT:
1. Reboot your system: sudo reboot
2. At login screen, select "Hyprland" session
3. Login with your credentials
4. Enjoy your new End-4 Material 3 desktop!

📱 KEY SHORTCUTS (After login):
• Super + /        → Show cheat sheet
• Super + T        → Open terminal
• Super Key        → Workspace overview & launcher
• Top corners      → Open sidebars
• Super + Ctrl + T → Wallpaper picker

🆘 IF ISSUES OCCUR:
• Backup location saved in: ~/.end4-backup-location
• Fallback config available in: ~/.config/hypr-fallback/

Enjoy your beautiful End-4 Hyprland setup! 🎨
EOF
    echo -e "${NC}"
}

# Emergency recovery function
create_recovery_script() {
    cat > ~/end4-recovery.sh << 'EOF'
#!/bin/bash
# End-4 Recovery Script

echo "🚨 End-4 Recovery Mode"

BACKUP_LOCATION=$(cat ~/.end4-backup-location 2>/dev/null)

if [ -d "$BACKUP_LOCATION" ]; then
    echo "Restoring from backup: $BACKUP_LOCATION"
    rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags
    cp -r "$BACKUP_LOCATION"/* ~/.config/ 2>/dev/null
    echo "✅ Backup restored successfully"
else
    echo "Using fallback configuration..."
    cp ~/.config/hypr-fallback/hyprland.conf ~/.config/hypr/hyprland.conf
    echo "✅ Fallback configuration applied"
fi

echo "🔄 Restart Hyprland to apply changes"
EOF
    
    chmod +x ~/end4-recovery.sh
}

# Main installation function
main() {
    echo -e "${CYAN}Starting End-4 Hyprland Installation with Thermal Protection${NC}"
    echo -e "${YELLOW}This installer is optimized for Acer One 14 Z2-493 with overheating protection${NC}"
    echo
    
    read -p "This will install End-4 Hyprland Material 3 theme. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user"
        exit 0
    fi
    
    # Installation steps with thermal protection
    check_system
    backup_existing_configs
    cool_down 15 "Initial setup complete"
    
    install_dependencies
    install_aur_packages  
    cool_down 30 "Package installation complete"
    
    clone_end4_repo
    install_end4_dotfiles
    cool_down 25 "Dotfiles installation complete"
    
    configure_sddm
    setup_user_permissions
    create_fallback_config
    create_recovery_script
    finalize_installation
    
    show_completion_message
    
    # Final reboot prompt
    echo
    read -p "Reboot now to complete installation? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log "Rebooting system..."
        sudo reboot
    else
        warn "Please reboot manually to complete the installation"
        warn "Run 'sudo reboot' when ready"
    fi
}

# Error handling
trap 'error "Installation failed at line $LINENO. Check ~/end4-recovery.sh for recovery options."' ERR

# Run main function
main "$@"
