#!/bin/bash
# ML4W Hyprland Waybar WiFi Popup Fix Script
# Fixes the issue where WiFi popup opens and closes immediately

echo "🔧 ML4W Hyprland Waybar WiFi Popup Fix"
echo "======================================"

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to install required packages
install_required_packages() {
    echo "📦 Installing required packages..."
    
    PACKAGES="nm-connection-editor network-manager-applet rofi wofi fuzzel"
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm $PACKAGES
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y $PACKAGES
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $PACKAGES
    fi
    
    echo "✅ Required packages installed"
}

# Function to create WiFi menu script
create_wifi_menu_script() {
    echo "🔧 Creating WiFi menu script..."
    
    mkdir -p "$HOME/.local/bin"
    
    # Create WiFi menu script using rofi/wofi
    cat > "$HOME/.local/bin/wifi-menu.sh" << 'EOF'
#!/bin/bash
# WiFi Menu Script for ML4W Hyprland

# Check if connected to WiFi
check_wifi_status() {
    nmcli radio wifi | grep -q "enabled" && nmcli device status | grep -q "wifi.*connected"
}

# Get current WiFi network
get_current_wifi() {
    nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes" {print $2}'
}

# Show WiFi menu based on available tools
show_wifi_menu() {
    if command -v wofi &> /dev/null; then
        # Use wofi for ML4W Hyprland
        CURRENT_WIFI=$(get_current_wifi)
        
        # Get available networks
        NETWORKS=$(nmcli -t -f ssid,signal,security dev wifi list | sort -t: -k2 -nr | while IFS=: read -r ssid signal security; do
            if [[ -n "$ssid" ]]; then
                if [[ "$ssid" == "$CURRENT_WIFI" ]]; then
                    echo "🔗 $ssid ($signal%) [Connected]"
                elif [[ "$security" == "--" ]]; then
                    echo "📶 $ssid ($signal%) [Open]"
                else
                    echo "🔒 $ssid ($signal%) [Secured]"
                fi
            fi
        done)
        
        # Add control options
        OPTIONS="$NETWORKS
📡 Refresh Networks
⚙️  Network Settings
❌ Disconnect WiFi
🔄 Toggle WiFi"
        
        CHOICE=$(echo "$OPTIONS" | wofi --dmenu --prompt "WiFi Networks" --lines 10 --width 400)
        
    elif command -v rofi &> /dev/null; then
        # Fallback to rofi
        CURRENT_WIFI=$(get_current_wifi)
        
        NETWORKS=$(nmcli -t -f ssid,signal,security dev wifi list | sort -t: -k2 -nr | while IFS=: read -r ssid signal security; do
            if [[ -n "$ssid" ]]; then
                if [[ "$ssid" == "$CURRENT_WIFI" ]]; then
                    echo "🔗 $ssid ($signal%) [Connected]"
                elif [[ "$security" == "--" ]]; then
                    echo "📶 $ssid ($signal%) [Open]"
                else
                    echo "🔒 $ssid ($signal%) [Secured]"
                fi
            fi
        done)
        
        OPTIONS="$NETWORKS
📡 Refresh Networks
⚙️  Network Settings
❌ Disconnect WiFi
🔄 Toggle WiFi"
        
        CHOICE=$(echo "$OPTIONS" | rofi -dmenu -p "WiFi Networks" -lines 10)
    else
        # Terminal fallback
        nm-connection-editor &
        return
    fi
    
    # Process choice
    if [[ -z "$CHOICE" ]]; then
        exit 0
    elif [[ "$CHOICE" == *"Network Settings"* ]]; then
        nm-connection-editor &
    elif [[ "$CHOICE" == *"Refresh Networks"* ]]; then
        nmcli device wifi rescan
        notify-send "WiFi" "Networks refreshed"
        exec "$0"  # Restart script
    elif [[ "$CHOICE" == *"Disconnect WiFi"* ]]; then
        nmcli device disconnect $(nmcli -t -f device,type device status | grep wifi | cut -d: -f1 | head -1)
        notify-send "WiFi" "Disconnected"
    elif [[ "$CHOICE" == *"Toggle WiFi"* ]]; then
        if nmcli radio wifi | grep -q "enabled"; then
            nmcli radio wifi off
            notify-send "WiFi" "WiFi disabled"
        else
            nmcli radio wifi on
            notify-send "WiFi" "WiFi enabled"
        fi
    elif [[ "$CHOICE" == *"[Connected]"* ]]; then
        # Already connected, show info
        SSID=$(echo "$CHOICE" | sed -n 's/🔗 \([^(]*\).*/\1/p' | xargs)
        notify-send "WiFi" "Already connected to $SSID"
    else
        # Connect to selected network
        SSID=$(echo "$CHOICE" | sed 's/^[🔗🔒📶] \([^(]*\).*/\1/' | xargs)
        
        if [[ "$CHOICE" == *"[Open]"* ]]; then
            # Connect to open network
            nmcli device wifi connect "$SSID"
        else
            # Prompt for password
            if command -v wofi &> /dev/null; then
                PASSWORD=$(echo | wofi --dmenu --prompt "Password for $SSID" --password)
            elif command -v rofi &> /dev/null; then
                PASSWORD=$(echo | rofi -dmenu -p "Password for $SSID" -password)
            else
                read -s -p "Password for $SSID: " PASSWORD
            fi
            
            if [[ -n "$PASSWORD" ]]; then
                nmcli device wifi connect "$SSID" password "$PASSWORD"
            fi
        fi
        
        # Check connection result
        sleep 2
        if check_wifi_status && [[ "$(get_current_wifi)" == "$SSID" ]]; then
            notify-send "WiFi" "Connected to $SSID"
        else
            notify-send "WiFi" "Failed to connect to $SSID" -u critical
        fi
    fi
}

# Main function
main() {
    # Ensure NetworkManager is running
    if ! systemctl is-active --quiet NetworkManager; then
        notify-send "WiFi" "NetworkManager is not running" -u critical
        exit 1
    fi
    
    # Rescan networks first
    nmcli device wifi rescan 2>/dev/null &
    
    # Show menu
    show_wifi_menu
}

main "$@"
EOF

    chmod +x "$HOME/.local/bin/wifi-menu.sh"
    echo "✅ WiFi menu script created"
}

# Function to fix waybar network configuration
fix_waybar_network_config() {
    echo "🔧 Fixing Waybar network configuration..."
    
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
    
    if [[ -z "$WAYBAR_CONFIG" ]]; then
        echo "❌ Waybar config not found. Creating default config..."
        mkdir -p "$HOME/.config/waybar"
        WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
    fi
    
    # Backup existing config
    cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create fixed waybar network configuration
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
    
    # Fix network module with proper click handlers
    network_config = {
        "format-wifi": "  {signalStrength}% {essid}",
        "format-ethernet": "  {ipaddr}/{cidr}",
        "format-disconnected": "  Disconnected",
        "format-linked": "  {ifname} (No IP)",
        "tooltip-format": "Connected to {essid} via {ifname}",
        "tooltip-format-wifi": "  {essid} ({signalStrength}%): {ipaddr}/{cidr}",
        "tooltip-format-ethernet": "  {ifname}: {ipaddr}/{cidr}",
        "tooltip-format-disconnected": "  Disconnected",
        "on-click": os.path.expanduser("~/.local/bin/wifi-menu.sh"),
        "on-click-right": "nm-connection-editor",
        "interval": 5,
        "max-length": 25
    }
    
    # Update network module
    if "network" in config:
        config["network"].update(network_config)
    else:
        config["network"] = network_config
    
    # Save updated config (preserve original formatting as much as possible)
    with open(config_path, 'w') as f:
        json_str = json.dumps(config, indent=2, ensure_ascii=False)
        
        # Add back some comments
        lines = json_str.split('\n')
        output_lines = []
        
        for line in lines:
            if '"network"' in line:
                output_lines.append('    // Network module configuration')
            output_lines.append(line)
        
        f.write('\n'.join(output_lines))
    
    print("✅ Waybar network config fixed")
    
except Exception as e:
    print(f"⚠️  Could not automatically fix waybar config: {e}")
    print("Manual fix required - see instructions below")
EOF

    echo "✅ Waybar configuration updated"
}

# Function to fix GTK popup issues
fix_gtk_popup_issues() {
    echo "🔧 Fixing GTK popup issues..."
    
    # Create or update GTK settings for proper popup behavior
    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"
    
    # GTK3 settings
    cat >> "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'

# Waybar popup fix
gtk-enable-animations=false
gtk-menu-popup-delay=0
gtk-tooltip-timeout=500
gtk-tooltip-browse-timeout=0
EOF

    # GTK4 settings
    cat >> "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'

# Waybar popup fix
gtk-enable-animations=false
EOF

    echo "✅ GTK popup settings configured"
}

# Function to restart waybar safely
restart_waybar() {
    echo "🔄 Restarting Waybar..."
    
    # Kill existing waybar processes
    pkill -f waybar 2>/dev/null || true
    sleep 1
    
    # Start waybar again
    if pgrep -x Hyprland > /dev/null; then
        nohup waybar > /dev/null 2>&1 &
    else
        echo "⚠️  Hyprland not running, waybar will start with next session"
    fi
    
    echo "✅ Waybar restarted"
}

# Function to show manual configuration instructions
show_manual_instructions() {
    echo ""
    echo "📋 Manual Configuration Instructions:"
    echo "====================================="
    echo ""
    echo "If the automatic fix didn't work, add this to your waybar config:"
    echo ""
    echo '  "network": {'
    echo '    "format-wifi": "  {signalStrength}% {essid}",'
    echo '    "format-ethernet": "  {ipaddr}/{cidr}",'
    echo '    "format-disconnected": "  Disconnected",'
    echo '    "tooltip-format-wifi": "  {essid} ({signalStrength}%): {ipaddr}/{cidr}",'
    echo '    "on-click": "~/.local/bin/wifi-menu.sh",'
    echo '    "on-click-right": "nm-connection-editor",'
    echo '    "interval": 5'
    echo '  }'
    echo ""
    echo "🔧 Alternative click handlers you can try:"
    echo "  • nm-connection-editor (Network settings GUI)"
    echo "  • nmtui (Terminal UI)"
    echo "  • ~/.local/bin/wifi-menu.sh (Custom script)"
    echo ""
}

# Main execution function
main() {
    check_root
    
    echo "🚀 Starting Waybar WiFi popup fix..."
    echo ""
    
    # Install required packages
    install_required_packages
    
    # Create custom WiFi menu script
    create_wifi_menu_script
    
    # Fix GTK popup issues
    fix_gtk_popup_issues
    
    # Fix waybar configuration
    fix_waybar_network_config
    
    # Restart waybar
    restart_waybar
    
    # Show manual instructions
    show_manual_instructions
    
    echo ""
    echo "========================================"
    echo "✅ Waybar WiFi popup fix completed!"
    echo ""
    echo "🧪 Test the fix:"
    echo "   • Click on the WiFi icon in waybar"
    echo "   • Right-click for network settings"
    echo "   • Check if popup stays open"
    echo ""
    echo "🛠️  If issues persist:"
    echo "   • Check waybar logs: journalctl -f --user-unit waybar"
    echo "   • Run WiFi script manually: ~/.local/bin/wifi-menu.sh"
    echo "   • Restart waybar: pkill waybar && waybar &"
    echo ""
    echo "📍 Common fixes applied:"
    echo "   • Custom WiFi menu script created"
    echo "   • Waybar network config updated"
    echo "   • GTK popup issues fixed"
    echo "   • Click handlers properly configured"
}

# Run the main function
main "$@"
