#!/bin/bash
# Fix Federation SDDM Theme Error

echo "🔧 Fixing Federation SDDM Theme Error"

# Switch to default theme temporarily
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

echo "✅ Switched to default SDDM theme"

# Create a working Federation theme
sudo mkdir -p /usr/share/sddm/themes/federation-fixed

# Create a working Main.qml
sudo tee /usr/share/sddm/themes/federation-fixed/Main.qml > /dev/null << 'EOF'
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
        }
        onLoginFailed: {
            password.selectAll()
            password.focus = true
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

    // Federation header
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
            text: "STARDATE: " + (((new Date().getFullYear() - 2323) * 1000) + (new Date().getTime() % 31536000000) / 31536000).toFixed(1)
        }

        Timer {
            interval: 10000
            running: true
            repeat: true
            onTriggered: {
                stardateText.text = "STARDATE: " + (((new Date().getFullYear() - 2323) * 1000) + (new Date().getTime() % 31536000000) / 31536000).toFixed(1)
            }
        }
    }

    // Login panel
    Rectangle {
        id: loginPanel
        anchors.centerIn: parent
        width: 400
        height: 300
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

            // User selection
            ComboBox {
                id: users
                width: 300
                height: 40
                model: userModel
                index: userModel.lastIndex
                color: "#ffd60a"
                borderColor: "#ffd60a"
                textColor: "#ffd60a"
                menuColor: "#001122"
                font.pixelSize: 16
                arrowIcon: "angle-down.png"

                KeyNavigation.backtab: loginButton
                KeyNavigation.tab: password
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
                            sddm.login(users.currentText, password.text, sessions.index)
                        }
                    }

                    KeyNavigation.backtab: users
                    KeyNavigation.tab: sessions
                }
            }

            // Session selection
            ComboBox {
                id: sessions
                width: 300
                height: 40
                model: sessionModel
                index: sessionModel.lastIndex
                color: "#ffd60a"
                borderColor: "#ffd60a"
                textColor: "#ffd60a"
                menuColor: "#001122"
                font.pixelSize: 16
                arrowIcon: "angle-down.png"

                KeyNavigation.backtab: password
                KeyNavigation.tab: loginButton
            }

            // Login button
            Rectangle {
                id: loginButton
                width: 300
                height: 40
                color: loginButtonArea.pressed ? "#cc9900" : "#ffd60a"
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "ENGAGE"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#001122"
                }

                MouseArea {
                    id: loginButtonArea
                    anchors.fill: parent
                    onClicked: sddm.login(users.currentText, password.text, sessions.index)
                }

                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(users.currentText, password.text, sessions.index)
                    }
                }

                KeyNavigation.backtab: sessions
                KeyNavigation.tab: users
            }
        }
    }

    // Time display
    Text {
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
        else
            loginButton.focus = true
    }
}
EOF

# Create theme.conf
sudo tee /usr/share/sddm/themes/federation-fixed/theme.conf > /dev/null << 'EOF'
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
sudo tee /usr/share/sddm/themes/federation-fixed/metadata.desktop > /dev/null << 'EOF'
[SddmGreeterTheme]
Name=Federation Fixed
Description=Fixed Federation themed login with Stardate
Author=ML4W Fixed
License=GPL
Version=1.0
Website=
Screenshot=
MainScript=Main.qml
ConfigFile=theme.conf
EOF

# Update SDDM config to use fixed theme
sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=federation-fixed
CursorTheme=breeze_cursors
ThemeDir=/usr/share/sddm/themes

[Users]
RememberLastSession=true
RememberLastUser=true

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions
EOF

echo "✅ Fixed Federation theme created and applied"

# Restart SDDM
sudo systemctl restart sddm

echo "🎉 Federation theme should now work without errors!"
echo "🚀 The login screen will show:"
echo "  • Federation styling with blue gradient"
echo "  • Real-time Stardate display"
echo "  • ENGAGE button for login"
echo "  • NumLock stays OFF"
