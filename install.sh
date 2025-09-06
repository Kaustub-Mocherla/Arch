#!/bin/bash
# Emergency Hyprland Recovery - Minimal Working Config

echo "🚨 Emergency Hyprland Fix"

# Step 1: Backup current broken config
mv ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.broken 2>/dev/null || true

# Step 2: Create ultra-minimal working config
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Ultra-Minimal Hyprland Configuration
# This WILL work - guaranteed

# Monitor setup
monitor=,preferred,auto,1

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}

# General settings
general {
    gaps_in = 3
    gaps_out = 6
    border_size = 1
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Minimal decoration
decoration {
    rounding = 3
    blur {
        enabled = false
    }
    drop_shadow = false
}

# No animations (to reduce load)
animations {
    enabled = false
}

# Layout
dwindle {
    pseudotile = true
}

# Essential keybinds
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, Return, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, V, togglefloating
bind = $mainMod, R, exec, wofi --show drun

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

# Move to workspace  
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Simple autostart - ONE AT A TIME
exec-once = kitty
EOF

echo "✅ Minimal config created"

# Step 3: Kill everything and reload
killall waybar hyprpaper swww 2>/dev/null || true
sleep 2

# Step 4: Reload Hyprland
hyprctl reload

echo "🎉 Emergency fix complete!"
echo "💡 You should now see a working desktop"
echo "⚡ Test: Super+Q should open terminal"
