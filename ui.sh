#!/bin/bash
# SDDM Recovery Script

echo "🚨 SDDM Recovery Mode"

# 1. Switch to default SDDM theme
sudo mkdir -p /etc/sddm.conf.d/
sudo tee /etc/sddm.conf.d/99-recovery.conf > /dev/null <<EOF
[General]
Numlock=off

[Theme]
Current=
EOF

# 2. Remove problematic Federation theme config
sudo rm -f /etc/sddm.conf
sudo rm -rf /etc/sddm.conf.d/federation*

# 3. Create minimal working SDDM config
sudo tee /etc/sddm.conf > /dev/null <<EOF
[General]
Numlock=off

[Theme]
Current=breeze

[Users]
RememberLastUser=true
RememberLastSession=true

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions
EOF

# 4. Restart SDDM
sudo systemctl restart sddm

echo "✅ SDDM should now work with default theme"
