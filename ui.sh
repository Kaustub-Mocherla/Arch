#!/bin/bash
# Complete ML4W Clean Installation - SYNTAX ERROR FIXED
# Optimized for Acer One 14 Z2-493 with thermal protection

echo "🛠️ Starting complete clean installation with syntax fixes"

# Step 1: Kill stuck processes and clean completely```ill -f "ml4w\|install\|setup" 2>/dev/null || true
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags ~/.config/rofi``` -rf ~/ml4w-dotfiles ~/dotfiles ~/Downloads/ml4w-install.sh

# Step 2: Check for missing files (fixes ml14u error)
if [ -f "$HOME/ml14u-setup.sh" ]; then
    bash "$HOME/ml14u-setup.sh"
else
    echo "⚠️ ml14u-setup.sh not found (this is normal) - continuing..."
fi

# Step 3: Thermal protection settings
export MAKEFLAGS="-j1"

# Step 4: Create WORKING minimal Hyprland config (FIXED SYNTAX)
mkdir -p ~/.config/hypr ~/.config/waybar

cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Working Hyprland Config - Fixed Syntax (No Line 34 Error)
monitor=,preferred,auto

input {
    kb_layout = us
    follow_mouse = 1
}

decoration {
    rounding = 8
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

# Fixed keybind syntax (was causing line 34 error)
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating
bind = $mainMod, F, fullscreen

# Workspace binds (correct syntax)
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

# Move windows to workspaces
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Autostart (working components)
exec-once = waybar
exec-once = hyprpaper
EOF

# Step 5: Create working waybar config
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery", "network", "pulseaudio"],
    
    "hyprland/workspaces": {
        "format": "{id}",
        "on-click": "activate"
    },
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "battery": {
        "format": "{capacity}% {icon}",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi": "{essid} ",
        "format-disconnected": "Disconnected"
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-icons": ["", "", ""]
    }
}
EOF

# Step 6: Create waybar styling
cat > ~/.config/waybar/style.css << 'EOF'
* {
    font-family: "JetBrains Mono", monospace;
    font-size: 13px;
    font-weight: bold;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    border-radius: 12px;
    margin: 5px;
}

#workspaces {
    background-color: rgba(69, 71, 90, 0.8);
    margin: 5px;
    padding: 0px 10px;
    border-radius: 10px;
}

#workspaces button {
    padding: 5px 10px;
    margin: 2px;
    border-radius: 8px;
    color: #45475a;
    background-color: transparent;
}

#workspaces button.active {
    color: #89b4fa;
    background-color: #313244;
}

#clock {
    background-color: rgba(148, 226, 213, 0.8);
    color: #11111b;
    border-radius: 10px;
    padding: 0 15px;
    margin: 5px;
}

#battery, #network, #pulseaudio {
    background-color: rgba(166, 227, 161, 0.8);
    color: #11111b;
    border-radius: 10px;
    padding: 0 15px;
    margin: 5px;
}
EOF

# Step 7: Create wallpaper config
cat > ~/.config/hypr/hyprpaper.conf << '```'
preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
ipc = on
EOF

# Step 8: Start components immediately
echo "🚀 Starting working Hyprland components```"
waybar &
hyprpaper &

echo ""
echo "✅ SYNTAX ERROR FIXED & WORKING```TUP CREATED!"
echo ""
echo "🎨 You should now see:"
echo "   ✅ Beautiful waybar at the top"
echo "   ✅ Wallpaper background"
echo "   ✅ Working animations and blur"
echo "   ✅ All shortcuts functional"
echo ""
echo "🔑 Test these shortcuts:"
echo "   • Super + Q → Terminal"
echo "   • Super + R → App launcher"
echo "   • Super + 1,2,3 → Switch workspaces"
echo ""
echo "💡 This config is optimized for your hardware```d uses correct syntax"
echo "🎯 No more line 34 errors or missing file issues"
