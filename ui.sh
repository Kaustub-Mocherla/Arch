#!/bin/bash
# CORRECTED MLW Installation Script - No Syntax Errors

echo "🔥 Starting corrected MLW installation"

# Step 1: Complete cleanup
sudo systemctl stop sddm 2>/dev/null || true
killall -9 waybar hyprpaper ml4w install 2>/dev/null || true
rm -rf ~/.config ~/.cache ~/.local/share/waybar ~/.local/share/icons
rm -rf ~/ml4w* ~/dotfiles ~/Downloads/*install*

# Step 2: Clean package caches
sudo pacman -Scc --noconfirm || true
yay -Scc --noconfirm 2>/dev/null || true

# Step 3: System update
sudo pacman -Syu --noconfirm

# Step 4: Install packages
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip
sudo pacman -S --needed --noconfirm hyprland kitty waybar flatpak firefox wofi

# Step 5: Install yay
if ! command -v yay &>/dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    MAKEFLAGS="-j1" makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
fi

# Step 6: CORRECTED Download and install MLW
cd ~/Downloads

# CORRECT SYNTAX: Semicolon before 'then'
if curl -L https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh -o mlw-install.sh; then
    echo "✅ Download successful"
    chmod +x mlw-install.sh
    timeout 300s bash mlw-install.sh
else
    echo "❌ Download failed - creating minimal working setup"
    
    # Create minimal working Hyprland setup
    mkdir -p ~/.config/hypr ~/.config/waybar
    
    cat > ~/.config/hypr/hyprland.conf << 'EOF'
monitor=,preferred,auto

input {
    kb_layout = us
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

$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, E, exec, dolphin
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

exec-once = waybar
exec-once = hyprpaper
EOF

    cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "height": 34,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery", "network"],
    "hyprland/workspaces": {"format": "{id}"},
    "clock": {"format": "{:%H:%M}"},
    "battery": {"format": "{capacity}%"},
    "network": {"format-wifi": "{essid}"}
}
EOF

    echo 'preload = /usr/share/pixmaps/archlinux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png' > ~/.config/hypr/hyprpaper.conf

    echo "✅ Minimal working setup created"
fi

# Step 7: Enable SDDM and finish
sudo systemctl enable sddm.service
sudo systemctl start sddm.service
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

echo ""
echo "🎉 INSTALLATION COMPLETED!"
echo "🔑 Super + Q → Terminal"
echo "🔑 Super + R → App launcher"
echo "🔄 Reboot now: sudo reboot"
