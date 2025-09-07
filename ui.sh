#!/bin/bash
# ML4W Hyprland WiFi Fix Script
# This script addresses common WiFi issues in ML4W Hyprland setups

echo "🔧 ML4W Hyprland WiFi Fix Script Starting..."

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to restart network services
restart_network_services() {
    echo "🔄 Restarting network services..."
    sudo systemctl restart NetworkManager
    sudo systemctl restart wpa_supplicant
    sleep 3
}

# Function to fix iwlwifi driver issues (common on Intel WiFi)
fix_iwlwifi_driver() {
    echo "🔧 Fixing iwlwifi driver issues..."
    
    # Remove and reload WiFi driver
    sudo modprobe -r iwlwifi
    sleep 2
    sudo modprobe iwlwifi
    
    # Fix common iwlwifi power management issues
    echo "options iwlwifi power_save=0" | sudo tee /etc/modprobe.d/iwlwifi.conf
    echo "options iwlmvm power_scheme=1" | sudo tee -a /etc/modprobe.d/iwlwifi.conf
}

# Function to fix NetworkManager configuration
fix_networkmanager_config() {
    echo "🔧 Fixing NetworkManager configuration..."
    
    # Backup existing config
    sudo cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.backup
    
    # Create optimized NetworkManager config
    sudo tee /etc/NetworkManager/NetworkManager.conf > /dev/null <<EOF
[main]
plugins=keyfile
dns=default
systemd-resolved=false

[wifi]
backend=iwd
powersave=2

[connection]
wifi.powersave=2
ethernet.cloned-mac-address=preserve
wifi.cloned-mac-address=preserve

[device]
wifi.scan-rand-mac-address=no
EOF
}

# Function to fix Waybar network module
fix_waybar_network() {
    echo "🔧 Fixing Waybar network module..."
    
    # Find ML4W waybar config
    WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
    
    if [[ -f "$WAYBAR_CONFIG" ]]; then
        # Backup waybar config
        cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.backup"
        
        # Fix network module configuration
        python3 << 'EOF'
import json
import re
import os

config_path = os.path.expanduser("~/.config/waybar/config.jsonc")
try:
    with open(config_path, 'r') as f:
        content = f.read()
    
    # Remove comments for JSON parsing
    content_clean = re.sub(r'//.*?\n', '\n', content)
    content_clean = re.sub(r'/\*.*?\*/', '', content_clean, flags=re.DOTALL)
    
    config = json.loads(content_clean)
    
    # Fix network module
    if "network" in config:
        config["network"].update({
            "format-wifi": "  {signalStrength}% {essid}",
            "format-ethernet": "  Connected",
            "format-disconnected": "  Disconnected",
            "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
            "tooltip-format-wifi": "{essid} ({signalStrength}%): {ipaddr}",
            "on-click": "nm-connection-editor",
            "interval": 5
        })
    
    # Write back with comments preserved structure
    with open(config_path, 'w') as f:
        f.write(json.dumps(config, indent=2))
    
    print("✅ Waybar network module fixed")
    
except Exception as e:
    print(f"⚠️  Waybar config fix failed: {e}")
EOF
    fi
}

# Function to reset WiFi connections
reset_wifi_connections() {
    echo "🔄 Resetting WiFi connections..."
    
    # Turn WiFi off and on
    nmcli radio wifi off
    sleep 2
    nmcli radio wifi on
    sleep 3
    
    # Refresh available networks
    nmcli device wifi rescan
    sleep 2
}

# Function to fix DNS issues
fix_dns_issues() {
    echo "🔧 Fixing DNS issues..."
    
    # Configure systemd-resolved
    sudo mkdir -p /etc/systemd/resolved.conf.d/
    sudo tee /etc/systemd/resolved.conf.d/dns.conf > /dev/null <<EOF
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
DNSSEC=yes
DNSOverTLS=yes
EOF
    
    sudo systemctl restart systemd-resolved
}

# Function to install missing WiFi packages
install_wifi_packages() {
    echo "📦 Checking and installing WiFi packages..."
    
    # Common WiFi packages
    PACKAGES="networkmanager network-manager-applet wireless_tools wpa_supplicant iw"
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm $PACKAGES
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y $PACKAGES
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $PACKAGES
    fi
}

# Function to restart Hyprland services
restart_hyprland_services() {
    echo "🔄 Restarting Hyprland-related services..."
    
    # Kill and restart waybar
    pkill waybar
    sleep 1
    waybar &
    
    # Restart network applet if running
    pkill nm-applet
    sleep 1
    nm-applet --indicator &
}

# Main execution
main() {
    check_root
    
    echo "🚀 Starting WiFi fixes for ML4W Hyprland..."
    echo "========================================"
    
    # Step 1: Install missing packages
    install_wifi_packages
    
    # Step 2: Fix iwlwifi driver (if Intel WiFi)
    if lspci | grep -i "intel.*wireless" &> /dev/null; then
        fix_iwlwifi_driver
    fi
    
    # Step 3: Fix NetworkManager
    fix_networkmanager_config
    
    # Step 4: Fix DNS
    fix_dns_issues
    
    # Step 5: Reset WiFi
    reset_wifi_connections
    
    # Step 6: Restart services
    restart_network_services
    
    # Step 7: Fix Waybar
    fix_waybar_network
    
    # Step 8: Restart Hyprland services
    restart_hyprland_services
    
    echo "========================================"
    echo "✅ WiFi fix script completed!"
    echo ""
    echo "🔄 Please reboot your system for all changes to take effect:"
    echo "   sudo reboot"
    echo ""
    echo "📡 After reboot, try connecting to WiFi with:"
    echo "   nmcli device wifi list"
    echo "   nmcli device wifi connect 'SSID' password 'PASSWORD'"
    echo ""
    echo "🛠️  If issues persist, check logs with:"
    echo "   journalctl -u NetworkManager -f"
}

# Run main function
main "$@"
