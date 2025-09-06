#!/bin/bash
# Emergency Fix - Modern Hyprland Syntax

echo "🔧 Creating working Hyprland config```th correct syntax"

# Clean all broken configs
rm -rf ~/.config/hypr ~/.config/waybar

# Create config with NEW syntax (fixes line 77 error)
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF``` Modern Hyprland Config - Updated Syntax
monitor=,preferred,auto

input {
    kb_layout = us
}

decoration {
    rounding = 8
    # NEW syntax (not drop_shadow)
    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
    blur {
        enabled = true
        size = 3
        passes = 1
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

animations {
    enabled = true
    animation = windows, 1, 7, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Keybinds
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Working autostart
exec-once = waybar
exec-once = hyprpaper
EOF

# Simple waybar
mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery"],
    "hyprland/workspaces": {"format": "{id}"},
    "clock": {"format": "{:%H:%M}"},
    "battery": {"format": "{capacity}%"}
}
EOF

# Basic wallpaper
echo 'preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png' > ~/.config/hypr/hyprpaper.conf

# Start components
waybar &
hyprpaper &

echo "✅ Fixed! You should now see waybar and wallpaper"```ho "🎨 Beautiful, modern Hyprland with```rrect syntax"
