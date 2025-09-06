#!/bin/bash
# Fixed Hyprland Config with New Syntax``` Remove broken ML4W configs
rm -rf ~/.config/hypr ~/.config/waybar

# Create working config with NEW decoration syntax
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Working Hyprland Config - Updated Syntax
monitor=,preferred,auto

input {
    kb_layout = us
    follow_mouse = 1
}

decoration {
    rounding = 8
    # NEW shadow syntax (not drop_shadow)
    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
    # NEW blur syntax
    blur {
        enabled = true
        size = 3
        passes = 1
        new_optimizations = true
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
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Essential keybinds
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, E, exec, dolphin

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

# Autostart
exec-once = waybar
exec-once = hyprpaper
EOF

# Create simple waybar config
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
        "format": "{id}"
    },
    "clock": {
        "format": "{:%H:%M}"
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

# Create waybar styling
cat > ~/.config/waybar/style.css << 'EOF'```{
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

# Create basic wallpaper config
cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png
ipc = on
EOF

# Start components
echo "🚀 Starting components..."
waybar &
hyprpaper &

echo "✅ Fixed Hyprland setup complete!"
echo "🎨 You should now see waybar and wallpaper!"````
