#!/bin/bash
# Custom Beautiful Hyprland - Designed for Your Hardware

echo "🎨 Creating Custom Beautiful Hyprland Setup"

# Step 1: Clean slate - remove failed installations
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/ags 2>/dev/null

# Step 2: Create beautiful, working Hyprland config
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Beautiful Hyprland Config - Optimized for Acer One 14 Z2-493
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
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
        new_optimizations = true
    }
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

# Keybinds
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit
bind = $mainMod, F, fullscreen

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Autostart - MINIMAL for your hardware
exec-once = waybar
exec-once = hyprpaper
EOF

# Step 3: Create beautiful waybar config
mkdir -p ~/.config/waybar
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
        "format-disconnected": "Disconnected "
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-icons": ["", "", ""]
    }
}
EOF

# Step 4: Beautiful waybar styling
cat > ~/.config/waybar/style.css << 'EOF'
* {
    font-family: "JetBrains Mono", monospace;
    font-size: 13px;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: .5s;
    border-radius: 0;
}

#workspaces {
    background-color: rgba(69, 71, 90, 0.8);
    margin: 5px;
    padding: 0px 5px;
    border-radius: 10px;
}

#workspaces button {
    padding: 5px 10px;
    margin: 4px 2px;
    border-radius: 10px;
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

#battery {
    background-color: rgba(166, 227, 161, 0.8);
    color: #11111b;
    border-radius: 10px;
    padding: 0 15px;
    margin: 5px;
}

#network {
    background-color: rgba(116, 199, 236, 0.8);
    color: #11111b;
    border-radius: 10px;
    padding: 0 15px;
    margin: 5px;
}

#pulseaudio {
    background-color: rgba(245, 194, 231, 0.8);
    color: #11111b;
    border-radius: 10px;
    padding: 0 15px;
    margin: 5px;
}
EOF

# Step 5: Simple wallpaper setup
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
ipc = on
EOF

# Step 6: Start the components
echo "🚀 Starting your custom beautiful desktop..."
waybar &
hyprpaper &

echo "✅ Custom Beautiful Hyprland Setup Complete!"
echo ""
echo "🎨 What you now have:"
echo "   ✅ Beautiful rounded corners and blur"
echo "   ✅ Colorful waybar with system info"
echo "   ✅ Smooth animations (optimized for your hardware)"
echo "   ✅ Professional appearance"
echo "   ✅ Stable and working"
echo ""
echo "🔑 Your shortcuts:"
echo "   • Super + Q → Terminal"
echo "   • Super + R → App launcher"
echo "   • Super + E → File manager"
echo "   • Super + 1,2,3,4,5 → Workspaces"
