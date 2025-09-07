#!/bin/bash
# ML4W Hyprland NumLock Control Script
# This script ensures NumLock behaves as desired on startup

echo "🔧 ML4W Hyprland NumLock Fix Script"
echo "==================================="

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to install numlockx if not present
install_numlockx() {
    echo "📦 Installing numlockx package..."
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm numlockx
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y numlockx
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y numlockx
    else
        echo "❌ Unsupported package manager. Please install 'numlockx' manually."
        exit 1
    fi
}

# Function to disable NumLock in BIOS/UEFI settings (reminder)
show_bios_reminder() {
    echo "💡 BIOS/UEFI Setting Reminder:"
    echo "   - Reboot and enter BIOS/UEFI settings"
    echo "   - Look for 'Boot Up NumLock State' or similar"
    echo "   - Set it to 'Off' or 'Disabled'"
    echo "   - This is the most reliable fix"
    echo ""
}

# Function to fix SDDM (display manager) NumLock setting
fix_sddm_numlock() {
    echo "🔧 Configuring SDDM to disable NumLock..."
    
    # Create SDDM config directory if it doesn't exist
    sudo mkdir -p /etc/sddm.conf.d/
    
    # Create or update SDDM configuration
    sudo tee /etc/sddm.conf.d/10-numlock.conf > /dev/null <<EOF
[General]
Numlock=off
EOF
    
    # Also check main SDDM config
    if [[ -f /etc/sddm.conf ]]; then
        sudo sed -i '/^\[General\]/,/^\[/{s/^Numlock=.*/Numlock=off/}' /etc/sddm.conf
    else
        sudo tee /etc/sddm.conf > /dev/null <<EOF
[General]
Numlock=off
EOF
    fi
    
    echo "✅ SDDM NumLock disabled"
}

# Function to fix LightDM NumLock setting
fix_lightdm_numlock() {
    echo "🔧 Configuring LightDM to disable NumLock..."
    
    # Find LightDM config files
    LIGHTDM_CONFIGS=(
        "/etc/lightdm/lightdm.conf"
        "/usr/share/lightdm/lightdm.conf.d/50-unity-greeter.conf"
        "/etc/lightdm/lightdm-gtk-greeter.conf"
    )
    
    for config in "${LIGHTDM_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            # Remove any existing greeter-setup-script
            sudo sed -i '/greeter-setup-script.*numlockx/d' "$config"
            
            # Add NumLock off command
            if grep -q "\[Seat:\*\]" "$config"; then
                sudo sed -i '/\[Seat:\*\]/a greeter-setup-script=/usr/bin/numlockx off' "$config"
            else
                echo -e "\n[Seat:*]\ngreeter-setup-script=/usr/bin/numlockx off" | sudo tee -a "$config" > /dev/null
            fi
            echo "✅ Updated $config"
        fi
    done
}

# Function to fix GDM NumLock setting
fix_gdm_numlock() {
    echo "🔧 Configuring GDM to disable NumLock..."
    
    # Create GDM dconf database directory
    sudo mkdir -p /etc/dconf/db/gdm.d/
    
    # Create GDM NumLock configuration
    sudo tee /etc/dconf/db/gdm.d/90-numlock > /dev/null <<EOF
[org/gnome/desktop/peripherals/keyboard]
numlock-state=false
remember-numlock-state=false
EOF
    
    # Update dconf database
    sudo dconf update
    echo "✅ GDM NumLock disabled"
}

# Function to create systemd service to force NumLock off
create_numlock_service() {
    echo "🔧 Creating systemd service to disable NumLock..."
    
    # Create script to disable NumLock
    sudo tee /usr/local/bin/numlock-off > /dev/null <<'EOF'
#!/bin/bash
# Disable NumLock on all TTYs
for tty in /dev/tty{1..6}; do
    if [[ -e "$tty" ]]; then
        /usr/bin/setleds -D -num < "$tty" 2>/dev/null || true
    fi
done

# Also disable in X11 if available
if command -v numlockx &> /dev/null; then
    DISPLAY=:0 numlockx off 2>/dev/null || true
fi
EOF
    
    sudo chmod +x /usr/local/bin/numlock-off
    
    # Create systemd service
    sudo tee /etc/systemd/system/numlock-off.service > /dev/null <<EOF
[Unit]
Description=Disable NumLock on startup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/numlock-off
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable numlock-off.service
    echo "✅ NumLock disable service created and enabled"
}

# Function to fix Hyprland startup
fix_hyprland_numlock() {
    echo "🔧 Configuring Hyprland to disable NumLock..."
    
    # Add NumLock disable to Hyprland config
    HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
    
    if [[ -f "$HYPR_CONFIG" ]]; then
        # Remove any existing NumLock lines
        sed -i '/numlockx/d' "$HYPR_CONFIG"
        
        # Add NumLock disable command to exec-once
        if grep -q "exec-once" "$HYPR_CONFIG"; then
            echo "exec-once = numlockx off" >> "$HYPR_CONFIG"
        else
            echo -e "\n# Disable NumLock on startup\nexec-once = numlockx off" >> "$HYPR_CONFIG"
        fi
        echo "✅ Added NumLock disable to Hyprland config"
    fi
}

# Function to fix desktop environment settings
fix_desktop_environment() {
    echo "🔧 Configuring desktop environment NumLock settings..."
    
    # KDE/Plasma settings
    if command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kcminputrc --group Keyboard --key NumLock 0
        echo "✅ KDE Plasma NumLock disabled"
    fi
    
    # GNOME settings
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.peripherals.keyboard numlock-state false 2>/dev/null || true
        gsettings set org.gnome.desktop.peripherals.keyboard remember-numlock-state false 2>/dev/null || true
        echo "✅ GNOME NumLock disabled"
    fi
    
    # XFCE settings
    if command -v xfconf-query &> /dev/null; then
        xfconf-query -c keyboards -p /Default/RestoreNumlock -s false 2>/dev/null || true
        echo "✅ XFCE NumLock disabled"
    fi
}

# Function to create user autostart entry
create_autostart_entry() {
    echo "🔧 Creating autostart entry to disable NumLock..."
    
    mkdir -p "$HOME/.config/autostart"
    
    cat > "$HOME/.config/autostart/numlock-off.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Disable NumLock
Comment=Turn off NumLock on login
Exec=numlockx off
Hidden=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF
    
    echo "✅ Autostart entry created"
}

# Function to detect current display manager
detect_display_manager() {
    if systemctl is-active --quiet sddm; then
        echo "sddm"
    elif systemctl is-active --quiet lightdm; then
        echo "lightdm"
    elif systemctl is-active --quiet gdm; then
        echo "gdm"
    elif systemctl is-active --quiet gdm3; then
        echo "gdm"
    else
        echo "unknown"
    fi
}

# Main execution function
main() {
    check_root
    
    echo "🚀 Starting NumLock fix for ML4W Hyprland..."
    echo ""
    
    # Show BIOS reminder
    show_bios_reminder
    
    # Install numlockx
    install_numlockx
    
    # Detect and fix display manager
    DM=$(detect_display_manager)
    echo "🔍 Detected display manager: $DM"
    
    case "$DM" in
        "sddm")
            fix_sddm_numlock
            ;;
        "lightdm")
            fix_lightdm_numlock
            ;;
        "gdm")
            fix_gdm_numlock
            ;;
        *)
            echo "⚠️  Unknown display manager, applying generic fixes"
            ;;
    esac
    
    # Create systemd service
    create_numlock_service
    
    # Fix Hyprland configuration
    fix_hyprland_numlock
    
    # Fix desktop environment settings
    fix_desktop_environment
    
    # Create autostart entry as fallback
    create_autostart_entry
    
    echo ""
    echo "========================================"
    echo "✅ NumLock fix script completed!"
    echo ""
    echo "📋 What was configured:"
    echo "   • Display manager settings"
    echo "   • Systemd service to disable NumLock"
    echo "   • Hyprland configuration"
    echo "   • Desktop environment settings"
    echo "   • Autostart entry as fallback"
    echo ""
    echo "🔄 Please reboot to apply all changes:"
    echo "   sudo reboot"
    echo ""
    echo "🛠️  Manual commands if needed:"
    echo "   numlockx off          # Disable NumLock now"
    echo "   numlockx on           # Enable NumLock now"
    echo "   systemctl status numlock-off.service  # Check service"
    echo ""
    echo "💡 For permanent fix, disable NumLock in BIOS/UEFI settings"
}

# Run the main function
main "$@"
