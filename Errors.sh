#!/bin/bash
set -e

echo "[*] Setting up Hyprland with Caelestia UI..."

# Ensure config directory exists
mkdir -p ~/.config/hypr

# Backup existing config if present
if [ -f ~/.config/hypr/hyprland.conf ]; then
    cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.backup.$(date +%s)
    echo "[i] Backed up existing hyprland.conf"
fi

# Write a minimal config with Super+Enter and autostart Caelestia
cat > ~/.config/hypr/hyprland.conf <<'EOF'
# Hyprland Base Config

# Main modifier key = Super (Windows key)
$mainMod = SUPER

# Launch terminal with Super+Enter
bind = $mainMod, RETURN, exec, kitty

# Launch browser with Super+B (optional)
bind = $mainMod, B, exec, firefox

# Exit Hyprland with Super+Shift+E
bind = $mainMod SHIFT, E, exit

# Autostart Caelestia Shell (QuickShell based)
exec-once = quickshell -c ~/.config/quickshell/caelestia/shell.qml
EOF

echo "[✓] Hyprland config updated with Super+Enter and Caelestia autostart."
echo "Next step: reboot and log into Hyprland session to see the UI."