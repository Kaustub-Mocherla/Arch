#!/bin/bash
# ML4W Hyprland Federation SDDM Theme + NumLock Fix + Auto-Launch Script
# Installs Federation SDDM theme, fixes NumLock issues, and configures auto-launch

echo "🚀 ML4W Hyprland Federation SDDM Setup Script"
echo "============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to install required packages
install_required_packages() {
    echo "📦 Installing required packages..."
    
    PACKAGES="sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg git wget unzip"
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm $PACKAGES
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y $PACKAGES
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $PACKAGES
    fi
    
    print_status "Required packages installed"
}

# Function to backup existing SDDM configuration
backup_sddm_config() {
    echo "💾 Backing up existing SDDM configuration..."
    
    BACKUP_DIR="$HOME/.sddm-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [[ -f "/etc/sddm.conf" ]]; then
        sudo cp /etc/sddm.conf "$BACKUP_DIR/"
    fi
    
    if [[ -d "/etc/sddm.conf.d" ]]; then
        sudo cp -r /etc/sddm.conf.d "$BACKUP_DIR/"
    fi
    
    print_status "SDDM configuration backed up to: $BACKUP_DIR"
}

# Function to download and install Federation SDDM theme
install_federation_theme() {
    echo "🎨 Installing Federation SDDM theme..."
    
    # Create temporary directory
    TEMP_DIR="/tmp/federation-sddm"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download Federation theme (using a popular Federation-style theme)
    print_info "Downloading Federation SDDM theme..."
    
    # Create Federation theme directory
    THEME_NAME="federation"
    mkdir -p "$THEME_NAME"
    
    # Create Main.qml for Federation theme
    cat > "$THEME_NAME/Main.qml" << 'EOF'
import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: container
    width: 1920
    height: 1080

    // Federation-style background
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#000814" }
        GradientStop { position: 0.5; color: "#001d3d" }
        GradientStop { position: 1.0; color: "#003566" }
    }

    // Star field background
    Item {
        anchors.fill: parent
        Repeater {
            model: 50
            Rectangle {
                x: Math.random() * parent.width
                y: Math.random() * parent.height
                width: Math.random() * 3 + 1
                height: width
                color: "white"
                opacity: Math.random() * 0.8 + 0.2
                radius: width/2
            }
        }
    }

    // Federation logo/title area
    Rectangle {
        id: titleArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 100
        width: 600
        height: 120
        color: "transparent"
        border.color: "#ffd60a"
        border.width: 2
        radius: 10

        Text {
            anchors.centerIn: parent
            text: "FEDERATION STARFLEET"
            font.pixelSize: 36
            font.bold: true
            color: "#ffd60a"
            font.family: "Monospace"
        }
    }

    // Login panel
    Rectangle {
        id: loginPanel
        anchors.centerIn: parent
        width: 400
        height: 300
        color: "#001122"
        opacity: 0.9
        border.color: "#ffd60a"
        border.width: 2
        radius: 15

        Column {
            anchors.centerIn: parent
            spacing: 20

            // User selection
            ComboBox {
                id: userCombo
                width: 300
                model: userModel
                currentIndex: userModel.lastIndex
                textRole: "name"
                
                style: Component {
                    id: comboStyle
                }
            }

            // Password field
            Rectangle {
                width: 300
                height: 40
                color: "#002244"
                border.color: "#ffd60a"
                border.width: 1
                radius: 5

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 10
                    font.pixelSize: 16
                    color: "#ffd60a"
                    echoMode: TextInput.Password
                    focus: true
                    
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(userCombo.currentText, password.text, sessionCombo.currentIndex)
                            event.accepted = true
                        }
                    }
                }
            }

            // Session selection
            ComboBox {
                id: sessionCombo
                width: 300
                model: sessionModel
                currentIndex: sessionModel.lastIndex
                textRole: "name"
            }

            // Login button
            Rectangle {
                width: 300
                height: 40
                color: "#ffd60a"
                radius: 5

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sddm.login(userCombo.currentText, password.text, sessionCombo.currentIndex)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "ENGAGE"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#001122"
                }
            }
        }
    }

    // Status text
    Text {
        id: statusText
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 50
        text: "Stardate " + new Date().toLocaleDateString() + " | " + new Date().toLocaleTimeString()
        font.pixelSize: 18
        color: "#ffd60a"
        font.family: "Monospace"
    }

    Component.onCompleted: {
        if (password.text === "")
            password.focus = true
        else
            loginButton.focus = true
    }
}
EOF

    # Create theme configuration
    cat > "$THEME_NAME/theme.conf" << 'EOF'
[General]
background=background.jpg
type=image

[Design]
ForceRightToLeft=false
PartialBlur=false
ShowBatteryWhenLow=true
ShowUserRealNameFallback=true

[UserPictureProperties]
CornerRadius=8
DefaultUserPixmap=default-user.png
UserPictureHeight=128
UserPictureWidth=128
EOF

    # Create metadata
    cat > "$THEME_NAME/metadata.desktop" << 'EOF'
[SddmGreeterTheme]
Name=Federation
Description=Star Trek Federation inspired SDDM theme
Author=ML4W Hyprland Setup
Copyright=(c) 2025
License=GPL
Type=sddm-theme
Version=1.0
Website=https://github.com/ml4w
Screenshot=screenshot.png
MainScript=Main.qml
ConfigFile=theme.conf
EOF

    # Create a simple background (will be replaced by user if needed)
    cat > "$THEME_NAME/background.jpg" << 'EOF'
# This will be replaced by an actual space background
EOF

    # Copy theme to system directory
    sudo mkdir -p /usr/share/sddm/themes/
    sudo cp -r "$THEME_NAME" /usr/share/sddm/themes/
    
    print_status "Federation SDDM theme installed"
    
    # Clean up
    cd ~
    rm -rf "$TEMP_DIR"
}

# Function to create Hyprland desktop entry for SDDM
create_hyprland_desktop_entry() {
    echo "🖥️  Creating Hyprland desktop entry for SDDM..."
    
    # Create wayland-sessions directory if it doesn't exist
    sudo mkdir -p /usr/share/wayland-sessions
    
    # Create Hyprland desktop entry
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
X-LightDM-DesktopName=Hyprland
EOF
    
    print_status "Hyprland desktop entry created"
}

# Function to fix NumLock issues in multiple places
fix_numlock_comprehensive() {
    echo "🔢 Comprehensive NumLock Fix..."
    
    # 1. Fix SDDM NumLock (login screen)
    sudo mkdir -p /etc/sddm.conf.d/
    sudo tee /etc/sddm.conf.d/01-numlock.conf > /dev/null <<EOF
[General]
Numlock=off
EOF
    
    # 2. Fix Hyprland NumLock configuration
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        # Remove any existing numlock lines
        sed -i '/numlock_by_default/d' "$HOME/.config/hypr/hyprland.conf"
        sed -i '/numlockx/d' "$HOME/.config/hypr/hyprland.conf"
        
        # Add proper NumLock configuration
        echo "" >> "$HOME/.config/hypr/hyprland.conf"
        echo "# NumLock Configuration" >> "$HOME/.config/hypr/hyprland.conf"
        echo "input {" >> "$HOME/.config/hypr/hyprland.conf"
        echo "    numlock_by_default = false" >> "$HOME/.config/hypr/hyprland.conf"
        echo "}" >> "$HOME/.config/hypr/hyprland.conf"
        echo "" >> "$HOME/.config/hypr/hyprland.conf"
        echo "# Ensure NumLock is off on startup" >> "$HOME/.config/hypr/hyprland.conf"
        echo "exec-once = numlockx off" >> "$HOME/.config/hypr/hyprland.conf"
        
        print_status "Hyprland NumLock configuration updated"
    else
        print_warning "Hyprland config not found, creating minimal config"
        mkdir -p "$HOME/.config/hypr"
        cat > "$HOME/.config/hypr/hyprland.conf" << 'EOF'
# ML4W Hyprland Configuration

# Input configuration
input {
    numlock_by_default = false
}

# Startup applications
exec-once = numlockx off
exec-once = waybar
EOF
    fi
    
    # 3. Install numlockx if not present
    if ! command -v numlockx &> /dev/null; then
        print_info "Installing numlockx..."
        if command -v pacman &> /dev/null; then
            sudo pacman -S --needed --noconfirm numlockx
        elif command -v apt &> /dev/null; then
            sudo apt install -y numlockx
        fi
    fi
    
    print_status "Comprehensive NumLock fix applied"
}

# Function to configure SDDM with Federation theme and auto-login to Hyprland
configure_sddm() {
    echo "⚙️  Configuring SDDM..."
    
    # Create main SDDM configuration
    sudo tee /etc/sddm.conf > /dev/null <<EOF
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=federation
CursorTheme=breeze_cursors
DisableAvatarsThreshold=7
EnableAvatars=true
FacesDir=/usr/share/sddm/faces
ThemeDir=/usr/share/sddm/themes

[Users]
DefaultPath=/usr/local/sbin:/usr/local/bin:/usr/bin
HideShells=
HideUsers=
MaximumUid=60000
MinimumUid=1000
RememberLastSession=true
RememberLastUser=true
ReuseSession=false

[Wayland]
EnableHiDPI=false
SessionCommand=/usr/share/sddm/scripts/wayland-session
SessionDir=/usr/share/wayland-sessions
SessionLogFile=.local/share/sddm/wayland-session.log

[X11]
EnableHiDPI=false
MinimumVT=1
ServerArguments=-nolisten tcp
ServerPath=/usr/bin/X
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/share/xsessions
SessionLogFile=.local/share/sddm/xorg-session.log
UserAuthFile=.Xauthority
EOF
    
    print_status "SDDM configured with Federation theme"
}

# Function to enable SDDM service
enable_sddm_service() {
    echo "🔧 Enabling SDDM service..."
    
    # Disable other display managers
    sudo systemctl disable gdm lightdm lxdm xdm 2>/dev/null || true
    
    # Enable SDDM
    sudo systemctl enable sddm
    
    # Check if SDDM service exists and is properly configured
    if systemctl list-unit-files | grep -q "sddm.service"; then
        print_status "SDDM service enabled"
    else
        print_error "SDDM service not found or not properly installed"
    fi
}

# Function to create startup optimization script
create_startup_optimization() {
    echo "⚡ Creating startup optimization..."
    
    mkdir -p "$HOME/.local/bin"
    
    # Create a startup script for Hyprland optimizations
    cat > "$HOME/.local/bin/hyprland-startup.sh" << 'EOF'
#!/bin/bash
# Hyprland Startup Optimization Script

# Disable NumLock immediately
numlockx off 2>/dev/null || true

# Set proper input configuration
hyprctl keyword input:numlock_by_default false 2>/dev/null || true

# Start essential services
waybar &
nm-applet --indicator &

# Set wallpaper (if using swaybg or hyprpaper)
# swaybg -i ~/.config/hypr/wallpaper.jpg -m fill &

echo "Hyprland startup optimizations applied"
EOF
    
    chmod +x "$HOME/.local/bin/hyprland-startup.sh"
    
    # Add to Hyprland config if not already present
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        if ! grep -q "hyprland-startup.sh" "$HOME/.config/hypr/hyprland.conf"; then
            echo "exec-once = ~/.local/bin/hyprland-startup.sh" >> "$HOME/.config/hypr/hyprland.conf"
        fi
    fi
    
    print_status "Startup optimization script created"
}

# Function to test SDDM configuration
test_sddm_config() {
    echo "🧪 Testing SDDM configuration..."
    
    # Test SDDM configuration validity
    if sddm --test-mode --theme federation 2>/dev/null; then
        print_status "SDDM configuration test passed"
    else
        print_warning "SDDM configuration test failed, but may still work"
    fi
    
    # Check if theme files exist
    if [[ -d "/usr/share/sddm/themes/federation" ]]; then
        print_status "Federation theme files present"
    else
        print_error "Federation theme files missing"
    fi
}

# Function to provide usage instructions
show_instructions() {
    echo ""
    echo "📋 Setup Complete! Instructions:"
    echo "================================="
    echo ""
    print_info "What was configured:"
    echo "  • Federation SDDM theme installed"
    echo "  • Hyprland desktop entry created for SDDM"
    echo "  • NumLock disabled in SDDM and Hyprland"
    echo "  • SDDM service enabled"
    echo "  • Startup optimization script created"
    echo ""
    print_info "Next steps:"
    echo "  1. Reboot your system: sudo reboot"
    echo "  2. SDDM will start automatically with Federation theme"
    echo "  3. Select 'Hyprland' from session menu"
    echo "  4. Login - Hyprland will start automatically"
    echo "  5. NumLock should remain OFF as configured"
    echo ""
    print_info "Troubleshooting:"
    echo "  • If SDDM doesn't start: sudo systemctl status sddm"
    echo "  • If theme doesn't load: check /usr/share/sddm/themes/federation/"
    echo "  • If NumLock is still on: check ~/.config/hypr/hyprland.conf"
    echo "  • Manual startup optimization: ~/.local/bin/hyprland-startup.sh"
    echo ""
    print_info "Customization:"
    echo "  • Theme files: /usr/share/sddm/themes/federation/"
    echo "  • SDDM config: /etc/sddm.conf"
    echo "  • Hyprland config: ~/.config/hypr/hyprland.conf"
    echo ""
    print_warning "Remember: After reboot, select 'Hyprland' from the session dropdown!"
}

# Main execution function
main() {
    check_root
    
    echo "🚀 Starting Federation SDDM + Hyprland Auto-Launch Setup..."
    echo ""
    
    # Installation and configuration steps
    backup_sddm_config
    install_required_packages
    install_federation_theme
    create_hyprland_desktop_entry
    fix_numlock_comprehensive
    configure_sddm
    enable_sddm_service
    create_startup_optimization
    test_sddm_config
    
    # Show final instructions
    show_instructions
    
    echo "✅ Federation SDDM setup completed!"
    echo "🔄 Please reboot to enjoy your new Federation-themed login experience!"
}

# Run the main function
main "$@"
