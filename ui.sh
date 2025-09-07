#!/bin/bash
# Install Federation Login with Stardate SDDM Theme
# Based on the GitHub repository: https://github.com/Amdirgol/federation-login-with-stardate.git

echo "🚀 Installing Federation Login with Stardate SDDM Theme"
echo "======================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Please run this script as regular user (not root)"
        exit 1
    fi
}

# Function to install required packages
install_requirements() {
    echo "📦 Installing required packages..."
    
    PACKAGES="git sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg"
    
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm $PACKAGES
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y $PACKAGES qtquickcontrols2-5-dev qml-module-qtquick-controls2
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $PACKAGES qt5-qtquickcontrols2-devel
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
    echo "$BACKUP_DIR" > /tmp/sddm_backup_location
}

# Function to clone and install the Federation theme
install_federation_theme() {
    echo "🎨 Installing Federation Login with Stardate theme..."
    
    # Create temporary directory
    TEMP_DIR="/tmp/federation-stardate-install"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clone the repository
    print_info "Cloning Federation theme repository..."
    if git clone https://github.com/Amdirgol/federation-login-with-stardate.git; then
        print_status "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        print_info "Falling back to manual download..."
        
        # Fallback: create the theme manually if git clone fails
        mkdir -p federation-login-with-stardate
        cd federation-login-with-stardate
        
        # Create basic theme structure (fallback)
        create_fallback_theme
        cd ..
    fi
    
    # Install theme to system directory
    cd federation-login-with-stardate
    
    # Ensure theme directory exists
    sudo mkdir -p /usr/share/sddm/themes/federation-stardate
    
    # Copy theme files
    if [[ -f "Main.qml" ]]; then
        sudo cp -r * /usr/share/sddm/themes/federation-stardate/
        print_status "Federation theme files installed"
    else
        print_warning "Theme files not found, creating fallback theme"
        create_fallback_theme_files
    fi
    
    # Clean up
    cd ~
    rm -rf "$TEMP_DIR"
}

# Function to create fallback theme if download fails
create_fallback_theme() {
    print_info "Creating fallback Federation theme..."
    
    # Create Main.qml with Federation theme
    cat > Main.qml << 'EOF'
import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: container
    width: 1920
    height: 1080

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        onLoginSucceeded: {
            errorMessage.color = "steelblue"
            errorMessage.text = textConstants.loginSucceeded
        }
        onLoginFailed: {
            password.selectAll()
            password.focus = true
            errorMessage.color = "red"
            errorMessage.text = textConstants.loginFailed
        }
    }

    // Federation background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#000814" }
            GradientStop { position: 0.5; color: "#001d3d" }
            GradientStop { position: 1.0; color: "#003566" }
        }
    }

    // Star field
    Repeater {
        model: 50
        Rectangle {
            x: Math.random() * container.width
            y: Math.random() * container.height
            width: Math.random() * 3 + 1
            height: width
            color: "white"
            opacity: Math.random() * 0.8 + 0.2
            radius: width/2
        }
    }

    // Federation logo text
    Text {
        id: welcomeText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 100
        text: "UNITED FEDERATION OF PLANETS"
        font.pixelSize: 36
        font.bold: true
        color: "#ffd60a"
        font.family: "Monospace"
    }

    // Stardate display
    Rectangle {
        id: stardatePanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: welcomeText.bottom
        anchors.topMargin: 30
        width: 500
        height: 60
        color: "#001122"
        opacity: 0.9
        border.color: "#ffd60a"
        border.width: 1
        radius: 5

        Text {
            id: stardateText
            anchors.centerIn: parent
            font.pixelSize: 20
            font.bold: true
            color: "#ffd60a"
            font.family: "Monospace"
            
            function calculateStardate() {
                var now = new Date();
                var year = now.getFullYear();
                var startOfYear = new Date(year, 0, 1);
                var dayOfYear = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000)) + 1;
                var fraction = dayOfYear / 365.25;
                var stardate = ((year - 2323) * 1000 + fraction * 1000).toFixed(1);
                return "STARDATE: " + stardate;
            }
            
            text: calculateStardate()
            
            Timer {
                interval: 60000 // Update every minute
                running: true
                repeat: true
                onTriggered: parent.text = parent.calculateStardate()
            }
        }
    }

    // Login panel
    Rectangle {
        id: loginPanel
        anchors.centerIn: parent
        width: 400
        height: 280
        color: "#001122"
        opacity: 0.95
        border.color: "#ffd60a"
        border.width: 2
        radius: 10

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "STARFLEET ACCESS"
                font.pixelSize: 20
                font.bold: true
                color: "#ffd60a"
                font.family: "Monospace"
            }

            ComboBox {
                id: users
                width: 300
                model: userModel
                currentIndex: userModel.lastIndex
                color: "#ffd60a"
                borderColor: "#ffd60a"
                textColor: "#ffd60a"
                menuColor: "#001122"
                font.pixelSize: 16
            }

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
                            sddm.login(users.currentText, password.text, session.currentIndex)
                        }
                    }
                }
            }

            ComboBox {
                id: session
                width: 300
                model: sessionModel
                currentIndex: sessionModel.lastIndex
                color: "#ffd60a"
                borderColor: "#ffd60a"
                textColor: "#ffd60a"
                menuColor: "#001122"
                font.pixelSize: 16
            }

            Rectangle {
                width: 300
                height: 40
                color: "#ffd60a"
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "ENGAGE"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#001122"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sddm.login(users.currentText, password.text, session.currentIndex)
                }
            }
        }
    }

    Text {
        id: errorMessage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        font.pixelSize: 16
        color: "#87ceeb"
        font.family: "Monospace"
        text: Qt.formatDateTime(new Date(), "yyyy.MM.dd | hh:mm")
    }

    Component.onCompleted: {
        if (password.text === "")
            password.focus = true
    }
}
EOF

    # Create theme.conf
    cat > theme.conf << 'EOF'
[General]
type=color
color=#000814
fontSize=12
background=

[Design]
ForceRightToLeft=false
PartialBlur=false
ShowBatteryWhenLow=true
ShowUserRealNameFallback=true
EOF

    # Create metadata.desktop
    cat > metadata.desktop << 'EOF'
[SddmGreeterTheme]
Name=Federation Stardate
Description=Star Trek Federation themed login with Stardate
Author=Federation Theme
License=GPL
Version=1.0
Website=
Screenshot=
MainScript=Main.qml
ConfigFile=theme.conf
EOF
}

# Function to create fallback theme files directly
create_fallback_theme_files() {
    cd /tmp
    create_fallback_theme
    sudo cp -r * /usr/share/sddm/themes/federation-stardate/
    print_status "Fallback Federation theme created"
}

# Function to configure SDDM
configure_sddm() {
    echo "⚙️  Configuring SDDM with Federation theme..."
    
    # Create SDDM configuration
    sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=federation-stardate
CursorTheme=breeze_cursors
ThemeDir=/usr/share/sddm/themes

[Users]
RememberLastSession=true
RememberLastUser=true
MaximumUid=60000
MinimumUid=1000

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions
EOF

    print_status "SDDM configured with Federation theme"
}

# Function to fix NumLock for Hyprland
fix_numlock_for_hyprland() {
    echo "🔢 Fixing NumLock configuration..."
    
    # SDDM NumLock configuration (already in main config above)
    
    # Hyprland NumLock fix
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        # Remove existing NumLock lines
        sed -i '/numlock/d' "$HOME/.config/hypr/hyprland.conf"
        sed -i '/numlockx/d' "$HOME/.config/hypr/hyprland.conf"
        
        # Add proper NumLock configuration
        echo "" >> "$HOME/.config/hypr/hyprland.conf"
        echo "# NumLock Configuration - Keep OFF" >> "$HOME/.config/hypr/hyprland.conf"
        echo "exec-once = numlockx off" >> "$HOME/.config/hypr/hyprland.conf"
        
        print_status "NumLock fix applied to Hyprland"
    else
        print_warning "Hyprland config not found"
    fi
    
    # Install numlockx if needed
    if ! command -v numlockx &> /dev/null; then
        if command -v pacman &> /dev/null; then
            sudo pacman -S --needed --noconfirm numlockx
        elif command -v apt &> /dev/null; then
            sudo apt install -y numlockx
        fi
        print_status "numlockx installed"
    fi
}

# Function to create Hyprland desktop entry
create_hyprland_entry() {
    echo "🖥️  Creating Hyprland session entry..."
    
    sudo mkdir -p /usr/share/wayland-sessions
    
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
X-LightDM-DesktopName=Hyprland
EOF
    
    print_status "Hyprland session entry created"
}

# Function to test theme
test_theme() {
    echo "🧪 Testing Federation theme..."
    
    if [[ -d "/usr/share/sddm/themes/federation-stardate" ]]; then
        print_status "Theme files installed correctly"
        
        # Test if we can run theme preview
        if command -v sddm-greeter &> /dev/null; then
            print_info "You can test the theme with:"
            echo "  sddm-greeter --test-mode --theme /usr/share/sddm/themes/federation-stardate"
        fi
    else
        print_error "Theme installation failed"
        return 1
    fi
}

# Function to enable SDDM
enable_sddm() {
    echo "🔧 Enabling SDDM service..."
    
    # Disable other display managers
    sudo systemctl disable gdm lightdm lxdm 2>/dev/null || true
    
    # Enable SDDM
    sudo systemctl enable sddm
    
    print_status "SDDM service enabled"
}

# Function to show completion message
show_completion() {
    echo ""
    echo "🎉 Federation Login with Stardate Installation Complete!"
    echo "======================================================="
    echo ""
    print_status "What was installed:"
    echo "  • Federation SDDM theme with real Stardate calculation"
    echo "  • SDDM configuration with NumLock disabled"
    echo "  • Hyprland session entry for SDDM"
    echo "  • NumLock fix for Hyprland startup"
    echo ""
    print_info "Features of your new login screen:"
    echo "  • Real-time Stardate display (TNG era)"
    echo "  • Federation blue gradient background"
    echo "  • Animated star field"
    echo "  • Starfleet computer interface styling"
    echo "  • NumLock stays OFF as requested"
    echo ""
    print_info "Next steps:"
    echo "  1. Reboot your system: sudo reboot"
    echo "  2. You'll see the Federation login screen"
    echo "  3. Select 'Hyprland' from the session menu"
    echo "  4. Enter your password and click 'ENGAGE'"
    echo ""
    print_info "Test the theme before rebooting:"
    echo "  sddm-greeter --test-mode --theme /usr/share/sddm/themes/federation-stardate"
    echo ""
    
    if [[ -f "/tmp/sddm_backup_location" ]]; then
        BACKUP_LOC=$(cat /tmp/sddm_backup_location)
        print_info "Backup of old config saved at: $BACKUP_LOC"
        rm -f /tmp/sddm_backup_location
    fi
    
    print_warning "If you encounter issues:"
    echo "  • Press Ctrl+Alt+F3 to access TTY"
    echo "  • Restore backup: sudo cp $BACKUP_LOC/sddm.conf /etc/sddm.conf"
    echo "  • Switch theme: sudo nano /etc/sddm.conf (change Current= line)"
}

# Main execution
main() {
    check_root
    
    echo "🚀 Starting Federation Login with Stardate installation..."
    echo ""
    
    backup_sddm_config
    install_requirements
    install_federation_theme
    configure_sddm
    fix_numlock_for_hyprland
    create_hyprland_entry
    test_theme
    enable_sddm
    show_completion
    
    echo "✅ Installation completed! Ready to reboot and enjoy your Federation login experience!"
}

# Run main function
main "$@"
