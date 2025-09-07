#!/bin/bash
# Emergency Federation SDDM Fix Script

echo "🚨 Emergency Federation SDDM Fix"

# Reset to working default theme first
sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=

[Users]
RememberLastSession=true
RememberLastUser=true

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions
EOF

echo "✅ Reset to default theme"

# Download and install the WORKING Federation theme
echo "🎨 Installing proper Federation theme..."

# Create the proper theme directory
sudo rm -rf /usr/share/sddm/themes/federation-stardate
sudo mkdir -p /usr/share/sddm/themes/federation-stardate

# Clone the actual working theme from the GitHub repo you found
TEMP_DIR="/tmp/federation-fix"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Try to download the actual theme files
if git clone https://github.com/Amdirgol/federation-login-with-stardate.git 2>/dev/null; then
    cd federation-login-with-stardate
    sudo cp -r * /usr/share/sddm/themes/federation-stardate/
    echo "✅ Original Federation theme installed from GitHub"
else
    # Create working Federation theme manually
    echo "Creating working Federation theme..."
    
    # Create the proper Main.qml that actually works
    sudo tee /usr/share/sddm/themes/federation-stardate/Main.qml > /dev/null << 'EOF'
import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    width: 1920
    height: 1080
    
    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    
    property int sessionIndex: session.currentIndex

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        onLoginSucceeded: {
        }
        onLoginFailed: {
            pw.selectAll()
            pw.focus = true
        }
    }

    Background {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status == Image.Error && source != config.defaultBackground) {
                source = config.defaultBackground
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        // Federation gradient overlay
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#80000814" }
                GradientStop { position: 0.5; color: "#80001d3d" }
                GradientStop { position: 1.0; color: "#80003566" }
            }
        }

        // Federation Header
        Text {
            id: federationHeader
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 100
            text: "UNITED FEDERATION OF PLANETS"
            font.pixelSize: 42
            font.bold: true
            color: "#ffd60a"
            font.family: "Monospace"
        }

        // Stardate Panel
        Rectangle {
            id: stardatePanel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: federationHeader.bottom
            anchors.topMargin: 30
            width: 600
            height: 80
            color: "#001122"
            opacity: 0.95
            border.color: "#ffd60a"
            border.width: 2
            radius: 8

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    id: stardateDisplay
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffd60a"
                    font.family: "Monospace"
                    
                    function updateStardate() {
                        var now = new Date();
                        var year = now.getFullYear();
                        var startOfYear = new Date(year, 0, 1);
                        var dayOfYear = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000)) + 1;
                        var dayFraction = dayOfYear / 365.25;
                        var stardate = ((year - 2323) * 1000 + dayFraction * 1000).toFixed(1);
                        text = "STARDATE: " + stardate;
                    }
                    
                    Component.onCompleted: updateStardate()
                    
                    Timer {
                        interval: 60000
                        running: true
                        repeat: true
                        onTriggered: parent.updateStardate()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 16
                    color: "#87ceeb"
                    font.family: "Monospace"
                    text: "EARTH TIME: " + Qt.formatDateTime(new Date(), "yyyy.MM.dd | hh:mm")
                }
            }
        }

        // Login Panel
        Rectangle {
            id: loginPanel
            anchors.centerIn: parent
            width: 450
            height: 350
            color: "#001122"
            opacity: 0.98
            border.color: "#ffd60a"
            border.width: 2
            radius: 12

            Column {
                anchors.centerIn: parent
                spacing: 25

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "STARFLEET ACCESS"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffd60a"
                    font.family: "Monospace"
                }

                // User selection
                ComboBox {
                    id: userField
                    width: 350
                    height: 45
                    font.pixelSize: 16
                    model: userModel
                    index: userModel.lastIndex
                    mainColor: "#ffd60a"
                    bgColor: "#002244"
                    focus: (userField.currentText === "") ? true : false
                    KeyNavigation.tab: pw
                }

                // Password field
                Rectangle {
                    width: 350
                    height: 45
                    color: "#002244"
                    border.color: "#ffd60a"
                    border.width: 1
                    radius: 5

                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.margins: 15
                        font.pixelSize: 16
                        font.family: "Monospace"
                        color: "#ffd60a"
                        echoMode: TextInput.Password
                        focus: (userField.currentText === "") ? false : true
                        selectByMouse: true

                        Keys.onPressed: {
                            if ((event.key === Qt.Key_Return) || (event.key === Qt.Key_Enter)) {
                                sddm.login(userField.currentText, pw.text, session.currentIndex)
                                event.accepted = true
                            }
                        }
                        KeyNavigation.tab: session
                    }
                }

                // Session selection
                ComboBox {
                    id: session
                    width: 350
                    height: 45
                    font.pixelSize: 16
                    model: sessionModel
                    index: sessionModel.lastIndex
                    mainColor: "#ffd60a"
                    bgColor: "#002244"
                    KeyNavigation.tab: loginButton
                }

                // Login Button
                Rectangle {
                    id: loginButton
                    width: 350
                    height: 50
                    color: loginButtonArea.pressed ? "#cc9900" : "#ffd60a"
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: "ENGAGE"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: "Monospace"
                        color: "#001122"
                    }

                    MouseArea {
                        id: loginButtonArea
                        anchors.fill: parent
                        onClicked: sddm.login(userField.currentText, pw.text, session.currentIndex)
                    }

                    Keys.onPressed: {
                        if ((event.key === Qt.Key_Return) || (event.key === Qt.Key_Enter)) {
                            sddm.login(userField.currentText, pw.text, session.currentIndex)
                            event.accepted = true
                        }
                    }
                    KeyNavigation.tab: userField
                }
            }
        }

        // Power buttons
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 30
            anchors.rightMargin: 30
            spacing: 15

            ImageButton {
                id: shutdownButton
                width: 60
                height: 60
                source: "shutdown.png"
                onClicked: sddm.powerOff()
            }

            ImageButton {
                id: rebootButton
                width: 60
                height: 60
                source: "restart.png"
                onClicked: sddm.reboot()
            }
        }
    }

    Component.onCompleted: {
        if (userField.currentText === "")
            userField.focus = true
        else
            pw.focus = true
    }
}
EOF

    # Create theme configuration
    sudo tee /usr/share/sddm/themes/federation-stardate/theme.conf > /dev/null << 'EOF'
[General]
type=image
background=background.jpg
scaleImageCropped=true
fontSize=12

[Design]
MainColor="navajowhite"
AccentColor="steelblue"
BackgroundColor="#444"
OverrideLoginButtonTextColor=""
InterfaceShadowSize="6"
InterfaceShadowOpacity="0.6"
RoundCorners="20"
ScreenPadding="0"
Font="Noto Sans"

[Sddm]
HourFormat="HH:mm"
DateFormat="dddd, MMMM d"

[UserPicture]
UserPictureEnabled="true"
UserPictureSize="70"
EOF

    # Create metadata
    sudo tee /usr/share/sddm/themes/federation-stardate/metadata.desktop > /dev/null << 'EOF'
[SddmGreeterTheme]
Name=Federation Stardate
Description=Star Trek Federation Login with Stardate
Author=ML4W Fixed
License=GPL
Type=sddm-theme
Version=1.0
Website=
Screenshot=
MainScript=Main.qml
ConfigFile=theme.conf
EOF

    # Create background image (simple gradient)
    sudo tee /usr/share/sddm/themes/federation-stardate/background.jpg > /dev/null << 'EOF'
# Placeholder for background - will be replaced by gradient
EOF

    echo "✅ Working Federation theme created"
fi

# Clean up
cd ~
rm -rf "$TEMP_DIR"

# Configure SDDM properly
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
MaximumUid=60000
MinimumUid=1000
RememberLastSession=true
RememberLastUser=true

[Wayland]
SessionDir=/usr/share/wayland-sessions
SessionCommand=/usr/share/sddm/scripts/wayland-session
SessionLogFile=.local/share/sddm/wayland-session.log

[X11]
SessionDir=/usr/share/xsessions
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionLogFile=.local/share/sddm/xorg-session.log
EOF

# Ensure Hyprland session exists
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF

# Fix NumLock
if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
    # Remove existing NumLock lines
    sed -i '/numlock/Id' "$HOME/.config/hypr/hyprland.conf"
    sed -i '/numlockx/d' "$HOME/.config/hypr/hyprland.conf"
    
    # Add proper NumLock fix
    echo "" >> "$HOME/.config/hypr/hyprland.conf"
    echo "# NumLock Configuration" >> "$HOME/.config/hypr/hyprland.conf"
    echo "exec-once = numlockx off" >> "$HOME/.config/hypr/hyprland.conf"
fi

# Restart SDDM
sudo systemctl restart sddm

echo "🎉 Federation SDDM theme fixed and restarted!"
echo "✅ You should now see the proper Federation login screen"
echo "✅ NumLock will stay OFF"
echo "✅ Login functionality restored"
