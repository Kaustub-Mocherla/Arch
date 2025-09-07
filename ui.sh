#!/bin/bash
# Emergency SDDM Fix - Restore Working Login

echo "🚨 Emergency SDDM Recovery"

# Switch to a working default theme
sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=breeze

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

# Remove problematic theme files
sudo rm -rf /usr/share/sddm/themes/federation-*

# Restart SDDM
sudo systemctl restart sddm

echo "✅ SDDM restored to working Breeze theme"
echo "🔄 You should now be able to login normally"
