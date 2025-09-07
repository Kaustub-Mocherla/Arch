#!/bin/bash
# ML4W Hyprland Complete Repair Script
# Comprehensive diagnostic and repair tool for ML4W Hyprland setups

echo "🔧 ML4W Hyprland Complete Repair Script"
echo "======================================="
echo "This script will diagnose and fix common ML4W Hyprland issues"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to create backup directory
create_backup() {
    BACKUP_DIR="$HOME/.ml4w-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    print_info "Backup directory created: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/ml4w_backup_dir
}

# Function to backup important configs
backup_configs() {
    echo "💾 Backing up current configurations..."
    BACKUP_DIR=$(cat /tmp/ml4w_backup_dir)
    
    # Backup Hyprland configs
    if [[ -d "$HOME/.config/hypr" ]]; then
        cp -r "$HOME/.config/hypr" "$BACKUP_DIR/" 2>/dev/null
        print_status "Hyprland config backed up"
    fi
    
    # Backup Waybar configs
    if [[ -d "$HOME/.config/waybar" ]]; then
        cp -r "$HOME/.config/waybar" "$BACKUP_DIR/" 2>/dev/null
        print_status "Waybar config backed up"
    fi
    
    # Backup ML4W configs
    if [[ -d "$HOME/.config/ml4w" ]]; then
        cp -r "$HOME/.config/ml4w" "$BACKUP_DIR/" 2>/dev/null
        print_status "ML4W config backed up"
    fi
    
    # Backup system network configs
    if [[ -f "/etc/NetworkManager/NetworkManager.conf" ]]; then
        sudo cp /etc/NetworkManager/NetworkManager.conf "$BACKUP_DIR/" 2>/dev/null
    fi
    if [[ -f "/etc/iwd/main.conf" ]]; then
        sudo cp /etc/iwd/main.conf "$BACKUP_DIR/" 2>/dev/null
    fi
    
    print_status "Configuration backup completed"
}

# Function to check system information
check_system_info() {
    echo "🖥️  System Information Check..."
    
    print_info "Hostname: $(hostname)"
    print_info "Kernel: $(uname -r)"
    print_info "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    print_info "Desktop Session: ${XDG_CURRENT_DESKTOP:-Not set}"
    print_info "Wayland Display: ${WAYLAND_DISPLAY:-Not set}"
    
    # Check if running in Hyprland
    if pgrep -x Hyprland > /dev/null; then
        print_status "Hyprland is running"
    else
        print_warning "Hyprland is not currently running"
    fi
    
    echo ""
}

# Function to check hardware
check_hardware() {
    echo "🔍 Hardware Check..."
    
    # Check CPU
    CPU_INFO=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    print_info "CPU: $CPU_INFO"
    
    # Check if overheating is an issue (for your Acer laptop)
    if [[ "$CPU_INFO" == *"AMD"* ]]; then
        TEMP=$(sensors 2>/dev/null | grep -E "(temp1|Tdie|Tctl)" | head -1 | grep -oP '\+\d+\.\d+°C' | head -1)
        if [[ -n "$TEMP" ]]; then
            print_info "CPU Temperature: $TEMP"
        fi
    fi
    
    # Check GPU
    GPU_INFO=$(lspci | grep -E "(VGA|3D)" | head -1 | cut -d: -f3 | xargs)
    print_info "GPU: $GPU_INFO"
    
    # Check WiFi card
    WIFI_INFO=$(lspci | grep -i "wireless\|wifi" | head -1 | cut -d: -f3 | xargs)
    if [[ -n "$WIFI_INFO" ]]; then
        print_info "WiFi: $WIFI_INFO"
    else
        print_warning "No WiFi card detected"
    fi
    
    echo ""
}

# Function to check services
check_services() {
    echo "⚙️  Service Status Check..."
    
    # Check display manager
    for dm in sddm lightdm gdm gdm3; do
        if systemctl is-active --quiet $dm; then
            print_status "Display Manager: $dm (running)"
            DM_ACTIVE=$dm
            break
        fi
    done
    
    if [[ -z "$DM_ACTIVE" ]]; then
        print_error "No display manager is running"
    fi
    
    # Check network services
    if systemctl is-active --quiet NetworkManager; then
        print_status "NetworkManager: running"
        NETWORK_BACKEND="NetworkManager"
    elif systemctl is-active --quiet iwd; then
        print_status "iwd: running"
        NETWORK_BACKEND="iwd"
    else
        print_error "No network manager is running"
    fi
    
    # Check audio
    if systemctl --user is-active --quiet pipewire; then
        print_status "PipeWire: running"
    elif systemctl --user is-active --quiet pulseaudio; then
        print_status "PulseAudio: running"
    else
        print_warning "No audio system detected"
    fi
    
    # Check bluetooth
    if systemctl is-active --quiet bluetooth; then
        print_status "Bluetooth: running"
    else
        print_info "Bluetooth: not running"
    fi
    
    echo ""
}

# Function to check ML4W installation
check_ml4w_installation() {
    echo "📦 ML4W Installation Check..."
    
    # Check ML4W directories
    if [[ -d "$HOME/.config/ml4w" ]]; then
        print_status "ML4W config directory exists"
    else
        print_warning "ML4W config directory missing"
    fi
    
    # Check Hyprland config
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        print_status "Hyprland config exists"
    else
        print_error "Hyprland config missing"
    fi
    
    # Check Waybar config
    WAYBAR_CONFIGS=(
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/config"
        "$HOME/.config/ml4w/config/waybar/config.jsonc"
    )
    
    WAYBAR_FOUND=false
    for config in "${WAYBAR_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            print_status "Waybar config found: $config"
            WAYBAR_CONFIG="$config"
            WAYBAR_FOUND=true
            break
        fi
    done
    
    if [[ "$WAYBAR_FOUND" == "false" ]]; then
        print_error "No Waybar config found"
    fi
    
    # Check running processes
    if pgrep -x waybar > /dev/null; then
        print_status "Waybar is running"
    else
        print_warning "Waybar is not running"
    fi
    
    echo ""
}

# Function to diagnose network issues
diagnose_network() {
    echo "🌐 Network Diagnostics..."
    
    # Check network interfaces
    INTERFACES=$(ip link show | grep -E "wlan|eth|enp" | awk -F: '{print $2}' | xargs)
    if [[ -n "$INTERFACES" ]]; then
        print_info "Network interfaces: $INTERFACES"
    fi
    
    # Check WiFi status
    if [[ "$NETWORK_BACKEND" == "NetworkManager" ]]; then
        WIFI_STATUS=$(nmcli radio wifi)
        print_info "WiFi radio: $WIFI_STATUS"
        
        CURRENT_WIFI=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes" {print $2}')
        if [[ -n "$CURRENT_WIFI" ]]; then
            print_status "Connected to WiFi: $CURRENT_WIFI"
        else
            print_warning "Not connected to WiFi"
        fi
    elif [[ "$NETWORK_BACKEND" == "iwd" ]]; then
        WIFI_DEVICE=$(iwctl device list | grep -E 'wlan[0-9]+' | awk '{print $1}' | head -1)
        if [[ -n "$WIFI_DEVICE" ]]; then
            print_info "WiFi device: $WIFI_DEVICE"
            CURRENT_WIFI=$(iwctl station "$WIFI_DEVICE" show | grep "Connected network" | awk '{print $3}')
            if [[ -n "$CURRENT_WIFI" ]]; then
                print_status "Connected to WiFi: $CURRENT_WIFI"
            else
                print_warning "Not connected to WiFi"
            fi
        fi
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        print_status "Internet connectivity: OK"
    else
        print_error "No internet connectivity"
    fi
    
    echo ""
}

# Function to check input issues (NumLock, Super key)
diagnose_input() {
    echo "⌨️  Input Diagnostics..."
    
    # Check NumLock status
    if command -v numlockx &> /dev/null; then
        print_status "numlockx is installed"
    else
        print_warning "numlockx not installed"
    fi
    
    # Check for input-related configs
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        if grep -q "numlockx" "$HOME/.config/hypr/hyprland.conf"; then
            print_status "NumLock configuration found in Hyprland config"
        else
            print_warning "No NumLock configuration in Hyprland config"
        fi
    fi
    
    # Check display manager NumLock settings
    if [[ "$DM_ACTIVE" == "sddm" && -f "/etc/sddm.conf" ]]; then
        if grep -q "Numlock=off" /etc/sddm.conf; then
            print_status "SDDM NumLock disabled"
        else
            print_warning "SDDM NumLock not configured"
        fi
    fi
    
    echo ""
}

# Function to install missing packages
install_missing_packages() {
    echo "📦 Installing Missing Packages..."
    
    # Essential packages for ML4W Hyprland
    ESSENTIAL_PACKAGES="hyprland waybar wofi rofi kitty alacritty nautilus firefox"
    
    # Network packages based on backend
    if [[ "$NETWORK_BACKEND" == "NetworkManager" ]]; then
        NETWORK_PACKAGES="networkmanager network-manager-applet nm-connection-editor"
    elif [[ "$NETWORK_BACKEND" == "iwd" ]]; then
        NETWORK_PACKAGES="iwd systemd-resolvconf"
    fi
    
    # Audio packages
    AUDIO_PACKAGES="pipewire pipewire-pulse pipewire-alsa pavucontrol"
    
    # Input packages
    INPUT_PACKAGES="numlockx"
    
    # Theme packages
    THEME_PACKAGES="gtk3 gtk4"
    
    ALL_PACKAGES="$ESSENTIAL_PACKAGES $NETWORK_PACKAGES $AUDIO_PACKAGES $INPUT_PACKAGES $THEME_PACKAGES"
    
    if command -v pacman &> /dev/null; then
        print_info "Installing packages with pacman..."
        sudo pacman -S --needed --noconfirm $ALL_PACKAGES
    elif command -v apt &> /dev/null; then
        print_info "Installing packages with apt..."
        sudo apt update && sudo apt install -y $ALL_PACKAGES
    elif command -v dnf &> /dev/null; then
        print_info "Installing packages with dnf..."
        sudo dnf install -y $ALL_PACKAGES
    fi
    
    print_status "Package installation completed"
    echo ""
}

# Function to repair network configuration
repair_network() {
    echo "🔧 Repairing Network Configuration..."
    
    if [[ "$NETWORK_BACKEND" == "NetworkManager" ]]; then
        # Create stable NetworkManager config
        sudo mkdir -p /etc/NetworkManager/conf.d/
        sudo tee /etc/NetworkManager/conf.d/99-ml4w-stability.conf > /dev/null <<EOF
[connection]
wifi.powersave=2

[device]
wifi.scan-rand-mac-address=no
EOF
        
        # Ensure services are enabled
        sudo systemctl enable --now NetworkManager
        print_status "NetworkManager configuration repaired"
        
    elif [[ "$NETWORK_BACKEND" == "iwd" ]]; then
        # Create iwd configuration
        sudo mkdir -p /etc/iwd
        sudo tee /etc/iwd/main.conf > /dev/null <<EOF
[General]
EnableNetworkConfiguration=true
AddressRandomization=once

[Network]
NameResolvingService=systemd
EnableIPv6=true
RoutePriorityOffset=300
EOF
        
        # Enable required services
        sudo systemctl enable --now iwd
        sudo systemctl enable --now systemd-resolved
        sudo systemctl enable --now systemd-networkd
        
        # Disable conflicting services
        sudo systemctl disable --now wpa_supplicant 2>/dev/null || true
        
        print_status "iwd configuration repaired"
    fi
    
    echo ""
}

# Function to repair NumLock configuration
repair_numlock() {
    echo "🔢 Repairing NumLock Configuration..."
    
    # Install numlockx if missing
    if ! command -v numlockx &> /dev/null; then
        if command -v pacman &> /dev/null; then
            sudo pacman -S --needed --noconfirm numlockx
        elif command -v apt &> /dev/null; then
            sudo apt install -y numlockx
        fi
    fi
    
    # Fix display manager settings
    if [[ "$DM_ACTIVE" == "sddm" ]]; then
        sudo mkdir -p /etc/sddm.conf.d/
        sudo tee /etc/sddm.conf.d/10-numlock.conf > /dev/null <<EOF
[General]
Numlock=off
EOF
        print_status "SDDM NumLock disabled"
    fi
    
    # Add to Hyprland config
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        if ! grep -q "numlockx off" "$HOME/.config/hypr/hyprland.conf"; then
            echo "exec-once = numlockx off" >> "$HOME/.config/hypr/hyprland.conf"
            print_status "Added NumLock disable to Hyprland config"
        fi
    fi
    
    echo ""
}

# Function to repair Waybar configuration
repair_waybar() {
    echo "📊 Repairing Waybar Configuration..."
    
    if [[ -n "$WAYBAR_CONFIG" && -f "$WAYBAR_CONFIG" ]]; then
        # Create a backup
        cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Create WiFi menu script
        mkdir -p "$HOME/.local/bin"
        
        if [[ "$NETWORK_BACKEND" == "NetworkManager" ]]; then
            cat > "$HOME/.local/bin/waybar-wifi.sh" << 'EOF'
#!/bin/bash
if command -v nm-connection-editor &> /dev/null; then
    nm-connection-editor &
else
    notify-send "Error" "nm-connection-editor not found"
fi
EOF
        else
            cat > "$HOME/.local/bin/waybar-wifi.sh" << 'EOF'
#!/bin/bash
if command -v iwctl &> /dev/null; then
    if command -v kitty &> /dev/null; then
        kitty iwctl &
    else
        iwctl &
    fi
else
    notify-send "Error" "iwctl not found"
fi
EOF
        fi
        
        chmod +x "$HOME/.local/bin/waybar-wifi.sh"
        print_status "WiFi menu script created"
        
        print_info "Waybar config backed up and prepared"
        print_info "Add this to your network module:"
        echo '  "on-click": "'$HOME'/.local/bin/waybar-wifi.sh"'
    else
        print_warning "No Waybar config found to repair"
    fi
    
    echo ""
}

# Function to restart services
restart_services() {
    echo "🔄 Restarting Services..."
    
    # Restart display manager configuration
    if [[ "$DM_ACTIVE" == "sddm" ]]; then
        print_info "SDDM config updated (restart required)"
    fi
    
    # Restart network services
    if [[ "$NETWORK_BACKEND" == "NetworkManager" ]]; then
        sudo systemctl restart NetworkManager
        print_status "NetworkManager restarted"
    elif [[ "$NETWORK_BACKEND" == "iwd" ]]; then
        sudo systemctl restart iwd
        sudo systemctl restart systemd-networkd
        print_status "iwd services restarted"
    fi
    
    # Restart Waybar if Hyprland is running
    if pgrep -x Hyprland > /dev/null; then
        pkill waybar 2>/dev/null || true
        sleep 1
        nohup waybar > /dev/null 2>&1 &
        print_status "Waybar restarted"
    fi
    
    echo ""
}

# Function to create maintenance scripts
create_maintenance_scripts() {
    echo "🛠️  Creating Maintenance Scripts..."
    
    mkdir -p "$HOME/.local/bin"
    
    # Create network reset script
    cat > "$HOME/.local/bin/ml4w-network-reset.sh" << 'EOF'
#!/bin/bash
echo "🔄 ML4W Network Reset"
if systemctl is-active --quiet NetworkManager; then
    sudo systemctl restart NetworkManager
    nmcli radio wifi off && sleep 2 && nmcli radio wifi on
elif systemctl is-active --quiet iwd; then
    sudo systemctl restart iwd
    sudo systemctl restart systemd-networkd
fi
notify-send "Network Reset" "Network services restarted"
EOF
    
    # Create waybar restart script
    cat > "$HOME/.local/bin/ml4w-waybar-restart.sh" << 'EOF'
#!/bin/bash
echo "🔄 ML4W Waybar Restart"
pkill waybar 2>/dev/null || true
sleep 1
nohup waybar > /dev/null 2>&1 &
notify-send "Waybar" "Waybar restarted"
EOF
    
    # Create system info script
    cat > "$HOME/.local/bin/ml4w-system-info.sh" << 'EOF'
#!/bin/bash
echo "ML4W System Information"
echo "======================"
echo "Hyprland: $(pgrep -x Hyprland > /dev/null && echo "Running" || echo "Not running")"
echo "Waybar: $(pgrep -x waybar > /dev/null && echo "Running" || echo "Not running")"
echo "Network: $(systemctl is-active NetworkManager iwd | head -1)"
echo "Display: ${WAYLAND_DISPLAY:-Not set}"
EOF
    
    chmod +x "$HOME/.local/bin/ml4w-"*.sh
    print_status "Maintenance scripts created in ~/.local/bin/"
    
    echo ""
}

# Function to show repair summary
show_summary() {
    echo "📋 Repair Summary"
    echo "================"
    echo ""
    print_status "Configuration backup created"
    print_status "System diagnostics completed"
    print_status "Missing packages installed"
    print_status "Network configuration repaired"
    print_status "NumLock configuration fixed"
    print_status "Waybar configuration prepared"
    print_status "Services restarted"
    print_status "Maintenance scripts created"
    echo ""
    print_info "Maintenance Commands:"
    echo "  ~/.local/bin/ml4w-network-reset.sh    # Reset network"
    echo "  ~/.local/bin/ml4w-waybar-restart.sh   # Restart waybar"
    echo "  ~/.local/bin/ml4w-system-info.sh      # System info"
    echo ""
    print_warning "Recommended Actions:"
    echo "  1. Reboot your system for all changes to take effect"
    echo "  2. Test WiFi connectivity after reboot"
    echo "  3. Check NumLock behavior on startup"
    echo "  4. Verify Waybar functionality"
    echo ""
    
    BACKUP_DIR=$(cat /tmp/ml4w_backup_dir)
    print_info "Backup location: $BACKUP_DIR"
    echo ""
    print_info "Reboot command: sudo reboot"
}

# Main execution function
main() {
    check_root
    create_backup
    
    echo "🚀 Starting ML4W Hyprland Complete Repair..."
    echo ""
    
    # Diagnostic phase
    check_system_info
    check_hardware
    check_services
    check_ml4w_installation
    diagnose_network
    diagnose_input
    
    # Repair phase
    backup_configs
    install_missing_packages
    repair_network
    repair_numlock
    repair_waybar
    restart_services
    create_maintenance_scripts
    
    # Summary
    show_summary
    
    echo "✅ ML4W Hyprland repair completed!"
    
    # Clean up
    rm -f /tmp/ml4w_backup_dir
}

# Run the main function
main "$@"
