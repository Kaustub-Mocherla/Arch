# Create proper waybar config
mkdir -p ~/.config/waybar

cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 4,
    
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{id}",
        "persistent-workspaces": {
            "1": [],
            "2": [],
            "3": [],
            "4": [],
            "5": []
        }
    },
    
    "hyprland/window": {
        "format": "{}",
        "max-length": 50,
        "separate-outputs": true
    },
    
    "tray": {
        "spacing": 10
    },
    
    "clock": {
        "format": "{:%H:%M}",
        "format-alt": "{:%Y-%m-%d %H:%M:%S}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{capacity}% {icon}",
        "format-charging": "{capacity}% 󰂄",
        "format-plugged": "{capacity}% ",
        "format-alt": "{time} {icon}",
        "format-icons": ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    },
    
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) ",
        "format-ethernet": "Connected ",
        "tooltip-format": "{ifname} via {gwaddr}",
        "format-linked": "{ifname} (No IP)",
        "format-disconnected": "Disconnected ⚠",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-bluetooth": "{volume}% {icon}󰂯",
        "format-bluetooth-muted": "󰝟 {icon}󰂯",
        "format-muted": "󰝟",
        "format-icons": {
            "headphone": "",
            "hands-free": "󰂑",
            "headset": "󰂑",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    }
}
EOF

# Create waybar stylesheet
cat > ~/.config/waybar/style.css << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 5 Free";
    font-weight: bold;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: .5s;
    border-radius: 0;
    margin: 0;
    padding: 0;
}

window#waybar.hidden {
    opacity: 0.2;
}

#workspaces {
    background-color: rgba(69, 71, 90, 0.8);
    margin: 5px;
    padding: 0px 1px;
    border-radius: 15px;
}

#workspaces button {
    padding: 5px 5px;
    margin: 4px 3px;
    border-radius: 15px;
    color: #45475a;
    background-color: transparent;
    transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.68);
}

#workspaces button.active {
    color: #89b4fa;
    background-color: #313244;
}

#workspaces button.urgent {
    color: #11111b;
    background-color: #a6e3a1;
}

#workspaces button:hover {
    background-color: #a6adc8;
    color: #313244;
}

#window,
#clock,
#battery,
#pulseaudio,
#network,
#tray {
    padding: 0 10px;
    margin: 5px 0;
}

#window {
    border-radius: 15px;
    background-color: rgba(69, 71, 90, 0.8);
    padding-left: 15px;
    padding-right: 15px;
}

#clock {
    border-radius: 15px;
    background-color: rgba(148, 226, 213, 0.8);
    color: #11111b;
}

#battery {
    border-radius: 15px;
    background-color: rgba(166, 227, 161, 0.8);
    color: #11111b;
}

#battery.critical:not(.charging) {
    background-color: #f38ba8;
    color: #11111b;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#network {
    border-radius: 15px;
    background-color: rgba(116, 199, 236, 0.8);
    color: #11111b;
}

#pulseaudio {
    border-radius: 15px;
    background-color: rgba(245, 194, 231, 0.8);
    color: #11111b;
}

#tray {
    border-radius: 15px;
    background-color: rgba(69, 71, 90, 0.8);
}

@keyframes blink {
    to {
        background-color: rgba(30, 30, 46, 0.5);
        color: #cdd6f4;
    }
}
EOF
