#!/bin/bash
# ML4W Hyprland WiFi Fix Script for iwd
# This script addresses common WiFi issues in ML4W Hyprland setups using iwd

echo "🔧 ML4W Hyprland WiFi Fix Script for iwd Starting..."

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to install required packages for iwd
install_iwd_packages() {
    echo "📦 Installing iwd and related packages..."
    
    PACKAGES="iwd dhcpcd systemd-resolvconf wofi rofi"
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm $PACKAGES
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y $PACKAGES
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $PACKAGES
    fi
    
    echo "✅ iwd packages installed"
}

# Function to configure iwd properly
configure_iwd() {
    echo "🔧 Configuring iwd..."
    
    # Create iwd configuration directory
    sudo mkdir -p /etc/iwd
    
    # Create iwd main configuration
    sudo tee /etc/iwd/main.conf > /dev/null <<EOF
[General]
EnableNetworkConfiguration=true
AddressRandomization=once

[Network]
NameResolvingService=systemd
EnableIPv6=true
RoutePriorityOffset=300

[Scan]
DisablePeriodicScan=false
EOF
    
    # Enable and start required services
    sudo systemctl enable --now iwd
    sudo systemctl enable --now systemd-resolved
    sudo systemctl enable --now systemd-networkd
    
    # Disable conflicting services
    sudo systemctl disable --now wpa_supplicant
    sudo systemctl disable --now dhcpcd
    
    echo "✅ iwd configured"
}

# Function to create iwd WiFi menu script
create_iwd_wifi_menu() {
    echo "🔧 Creating iwd WiFi menu script..."
    
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/iwd-wifi-menu.sh" << 'EOF'
#!/bin/bash
# iwd WiFi Menu Script for ML4W Hyprland

# Check if iwd is running
check_iwd_status() {
    systemctl is-active --quiet iwd
}

# Get current WiFi device
get_wifi_device() {
    iwctl device list | grep -E 'wlan[0-9]+' | awk '{print $1}' | head -1
}

# Get current connection
get_current_connection() {
    DEVICE=$(get_wifi_device)
    if [[ -n "$DEVICE" ]]; then
        iwctl station "$DEVICE" show | grep "Connected network" | awk '{print $3}'
    fi
}

# Show WiFi menu
show_iwd_menu() {
    if ! check_iwd_status; then
        notify-send "WiFi Error" "iwd service is not running" -u critical
        return 1
    fi
    
    DEVICE=$(get_wifi_device)
    if [[ -z "$DEVICE" ]]; then
        notify-send "WiFi Error" "No WiFi device found" -u critical
        return 1
    fi
    
    # Determine menu command
    if command -v wofi &> /dev/null; then
        MENU_CMD="wofi --dmenu --prompt 'WiFi Networks' --lines 10 --width 400"
    elif command -v rofi &> /dev/null; then
        MENU_CMD="rofi -dmenu -p 'WiFi Networks' -lines 10"
    else
        # Terminal fallback
        iwctl
        return
    fi
    
    # Get current connection
    CURRENT=$(get_current_connection)
    
    # Scan for networks
    iwctl station "$DEVICE" scan
    sleep 2
    
    # Get available networks
    NETWORKS=$(iwctl station "$DEVICE" get-networks | tail -n +5 | while read -r line; do
        if [[ -n "$line" && "$line" != *"----"* ]]; then
            SSID=$(echo "$line" | awk '{print $1}')
            SECURITY=$(echo "$line" | awk '{print $2}')
            SIGNAL=$(echo "$line" | awk '{print $3}')
            
            if [[ "$SSID" == "$CURRENT" ]]; then
                echo "🔗 $SSID ($SIGNAL) [Connected]"
            elif [[ "$SECURITY" == "open" ]]; then
                echo "📶 $SSID ($SIGNAL) [Open]"
            else
                echo "🔒 $SSID ($SECURITY) ($SIGNAL)"
            fi
        fi
    done | sort -k2 -nr)
    
    # Add control options
    OPTIONS="$NETWORKS
📡 Refresh Networks
📊 Connection Info
❌ Disconnect
🔄 Toggle WiFi
⚙️  iwd Console"
    
    CHOICE=$(echo "$OPTIONS" | eval $MENU_CMD)
    
    # Process choice
    case "$CHOICE" in
        *"Refresh Networks"*)
            iwctl station "$DEVICE" scan
            notify-send "WiFi" "Networks refreshed"
            exec "$0"  # Restart script
            ;;
        *"Connection Info"*)
            if [[ -n "$CURRENT" ]]; then
                IP=$(ip addr show "$DEVICE" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
                notify-send "WiFi Info" "Connected to: $CURRENT\nDevice: $DEVICE\nIP: $IP" -t 5000
            else
                notify-send "WiFi Info" "Not connected to WiFi"
            fi
            ;;
        *"Disconnect"*)
            iwctl station "$DEVICE" disconnect
            notify-send "WiFi" "Disconnected"
            ;;
        *"Toggle WiFi"*)
            if iwctl adapter list | grep -q "on"; then
                iwctl adapter phy0 set-property Powered off
                notify-send "WiFi" "WiFi disabled"
            else
                iwctl adapter phy0 set-property Powered on
                notify-send "WiFi" "WiFi enabled"
            fi
            ;;
        *"iwd Console"*)
            if command -v kitty &> /dev/null; then
                kitty iwctl &
            elif command -v alacritty &> /dev/null; then
                alacritty -e iwctl &
            else
                iwctl &
            fi
            ;;
        *"[Connected]"*)
            # Already connected, show info
            SSID=$(echo "$CHOICE" | sed -n 's/🔗 \([^ ]*\).*/\1/p')
            notify-send "WiFi" "Already connected to $SSID"
            ;;
        "")
            # No choice made
            exit 0
            ;;
        *)
            # Connect to selected network
            SSID=$(echo "$CHOICE" | sed 's/^[🔗🔒📶] \([^ ]*\).*/\1/')
            
            if [[ "$CHOICE" == *"[Open]"* ]]; then
                # Connect to open network
                iwctl station "$DEVICE" connect "$SSID"
                notify-send "WiFi" "Connecting to $SSID..."
            else
                # Prompt for password
                if command -v wofi &> /dev/null; then
                    PASSWORD=$(echo | wofi --dmenu --prompt "Password for $SSID" --password)
                elif command -v rofi &> /dev/null; then
                    PASSWORD=$(echo | rofi -dmenu -p "Password for $SSID" -password)
                else
                    read -s -p "Password for $SSID: " PASSWORD
                    echo
                fi
                
                if [[ -n "$PASSWORD" ]]; then
                    iwctl station "$DEVICE" connect "$SSID" --passphrase "$PASSWORD"
                    notify-send "WiFi" "Connecting to $SSID..."
                fi
            fi
            
            # Check connection result after a delay
            sleep 3
            NEW_CONNECTION=$(get_current_connection)
            if [[ "$NEW_CONNECTION" == "$SSID" ]]; then
                notify-send "WiFi" "Successfully connected to $SSID"
            else
                notify-send "WiFi" "Failed to connect to $SSID" -u critical
            fi
            ;;
    esac
}

# Main function
main() {
    show_iwd_menu
}

main "$@"
EOF

    chmod +x "$HOME/.local/bin/iwd-wifi-menu.sh"
    echo "✅ iwd WiFi menu script created"
}

# Function to fix waybar network configuration for iwd
fix_waybar_iwd_config() {
    echo "🔧 Fixing Waybar network configuration for iwd..."
    
    # Find ML4W waybar config
    WAYBAR_CONFIG=""
    POSSIBLE_CONFIGS=(
        "$HOME/.config/ml4w/config/waybar/config.jsonc"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/config"
        "$HOME/.config/ml4w-hyprland/waybar/config.jsonc"
    )
    
    for config in "${POSSIBLE_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            WAYBAR_CONFIG="$config"
            break
        fi
    done
    
    if [[ -n "$WAYBAR_CONFIG" ]]; then
        # Backup existing config
        cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Create iwd-compatible waybar network configuration
        python3 << EOF
import json
import re
import os

config_path = "$WAYBAR_CONFIG"

try:
    with open(config_path, 'r') as f:
        content = f.read()
    
    # Remove comments for JSON parsing
    content_clean = re.sub(r'//.*?\n', '\n', content)
    content_clean = re.sub(r'/\*.*?\*/', '', content_clean, flags=re.DOTALL)
    
    config = json.loads(content_clean)
    
    # Fix network module for iwd
    network_config = {
        "interface": "wlan0",
        "format-wifi": "  {signalStrength}% {essid}",
        "format-ethernet": "  {ipaddr}/{cidr}",
        "format-linked": "  {ifname} (No IP)",
        "format-disconnected": "  Disconnected",
        "tooltip-format": "Connected via {ifname}",
        "tooltip-format-wifi": "  {essid} ({signalStrength}%)\nIP: {ipaddr}/{cidr}\nFreq: {frequency}MHz",
        "tooltip-format-ethernet": "  {ifname}: {ipaddr}/{cidr}",
        "tooltip-format-disconnected": "  Disconnected",
        "on-click": os.path.expanduser("~/.local/bin/iwd-wifi-menu.sh"),
        "on-click-right": "iwctl",
        "interval": 5,
        "max-length": 30
    }
    
    # Update network module
    if "network" in config:
        config["network"].update(network_config)
    else:
        config["network"] = network_config
    
    # Save updated config
    with open(config_path, 'w') as f:
        f.write(json.dumps(config, indent=2, ensure_ascii=False))
    
    print("✅ Waybar network config updated for iwd")
    
except Exception as e:
    print(f"⚠️  Could not automatically fix waybar config: {e}")
EOF
    else
        echo "❌ Waybar config not found"
    fi
}

# Function to create systemd-networkd configuration
create_networkd_config() {
    echo "🔧 Creating systemd-networkd configuration..."
    
    sudo mkdir -p /etc/systemd/network
    
    # Create wireless network configuration
    sudo tee /etc/systemd/network/25-wireless.network > /dev/null <<EOF
[Match]
Name=wlan*

[Network]
DHCP=yes
DNS=8.8.8.8
DNS=1.1.1.1
IPForward=no
IPv6AcceptRA=yes

[DHCP]
RouteMetric=20
EOF
    
    echo "✅ systemd-networkd configuration created"
}

# Function to restart waybar
restart_waybar() {
    echo "🔄 Restarting Waybar..."
    
    pkill waybar 2>/dev/null || true
    sleep 1
    
    if pgrep -x Hyprland > /dev/null; then
        nohup waybar > /dev/null 2>&1 &
        echo "✅ Waybar restarted"
    else
        echo "⚠️  Hyprland not running, waybar will start with next session"
    fi
}

# Function to show iwd usage instructions
show_iwd_instructions() {
    echo ""
    echo "📋 iwd Usage Instructions:"
    echo "========================="
    echo ""
    echo "🔧 Basic iwd commands:"
    echo "   iwctl                          # Start interactive mode"
    echo "   iwctl device list              # List WiFi devices"
    echo "   iwctl station wlan0 scan       # Scan for networks"
    echo "   iwctl station wlan0 get-networks # List available networks"
    echo "   iwctl station wlan0 connect SSID # Connect to network"
    echo "   iwctl station wlan0 disconnect  # Disconnect"
    echo ""
    echo "🎯 Waybar integration:"
    echo "   • Left-click WiFi icon: Open custom menu"
    echo "   • Right-click WiFi icon: Open iwctl terminal"
    echo ""
    echo "🛠️  Troubleshooting:"
    echo "   sudo systemctl status iwd      # Check iwd status"
    echo "   sudo journalctl -u iwd -f     # Check iwd logs"
    echo "   ~/.local/bin/iwd-wifi-menu.sh # Test menu script"
    echo ""
}

# Main execution function
main() {
    check_root
    
    echo "🚀 Starting iwd WiFi fixes for ML4W Hyprland..."
    echo "==============================================="
    
    # Install iwd and related packages
    install_iwd_packages
    
    # Configure iwd
    configure_iwd
    
    # Create systemd-networkd config
    create_networkd_config
    
    # Create iwd WiFi menu
    create_iwd_wifi_menu
    
    # Fix waybar configuration
    fix_waybar_iwd_config
    
    # Restart waybar
    restart_waybar
    
    # Show usage instructions
    show_iwd_instructions
    
    echo "==============================================="
    echo "✅ iwd WiFi fix completed!"
    echo ""
    echo "🔄 Please reboot to ensure all services start correctly:"
    echo "   sudo reboot"
    echo ""
    echo "📡 After reboot, connect to WiFi using:"
    echo "   1. Click WiFi icon in waybar (custom menu)"
    echo "   2. Right-click for iwctl console"
    echo "   3. Command line: iwctl station wlan0 connect 'SSID'"
    echo ""
    echo "🛠️  If issues persist:"
    echo "   • Check services: systemctl status iwd systemd-networkd"
    echo "   • View logs: journalctl -u iwd -f"
    echo "   • Test menu: ~/.local/bin/iwd-wifi-menu.sh"
}

# Run main function
main "$@"
