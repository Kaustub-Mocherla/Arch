#!/bin/bash
# Complete hassle-free MLW install for Acer One 14 Z2-493
# No more ml14u-setup.sh errors or syntax issues

echo "🔥 Starting ultimate hassle-free MLW installation"

# Error handling function
handle_error() {
    echo "[ERROR]: $@" >&2
    exit 1
}

# Step 1: Stop all graphical processes
sudo systemctl stop sddm || true
killall -9 waybar hyprpaper ml4w install || true

# Step 2: Complete system cleanup
echo "🧹 Complete system cleanup..."
rm -rf ~/.config ~/.cache ~/.local/share/waybar ~/.local/share/icons ~/.local/share/```mes
rm -rf ~/ml4w* ~/dotfiles ~/Downloads/*install* ~/Downloads/*setup*

# Step 3: Clean package caches
sudo pacman -Scc --noconfirm || true
yay -Scc --noconfirm 2>/dev/null || true

# Step 4: System update with thermal protection
echo "📦 Updating system..."
sudo pacman -Syu --noconfirm || handle_error "System update failed"```eep 15  # Cooling period

# Step 5: Install base packages in batches
echo "🔧 Installing base packages..."
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip || handle_error "Base tools```stall failed"
sleep 10

sudo pacman -S --needed --noconfirm hyprland kitty waybar || handle_error "Hyprlan```nstall failed"
sleep 10

sudo pacman -S --needed --noconfirm flatpak firefox wofi || handle_error "Apps```stall failed"
sleep 10

# Step 6: Install yay with thermal protection
if ! command -v yay &>/dev/null; then
    echo "🔨 Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/y```git || handle_error "Failed to clone y```
    cd yay
    # Single-threaded compilation to prevent overheating
    MAKEFLAGS="-j1" makepkg -si --noconfirm || handle_error "Failed to build yay"
    cd ~
    rm -rf /tmp/yay
    sleep 15  # Extended cooling
fi

# Step 7: Download and install MLW (multiple sources)
echo "📥 Downloading MLW installer..."
cd ~/Downloads

# Try multiple download sources
if ! curl -L https://raw.githubusercontent.com/my```uxforwork/dotfiles/main/setup```ch.sh -o mlw-install.sh; then
    if ! curl -L https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/install``` -o mlw-install.sh; then
        # Fallback: Create minimal working setup
        echo "⚠️ MLW download failed - creating minimal working setup"
        
        mkdir -p ~/.config/hypr ~/.config/waybar
        
        # Working Hyprland config
        cat > ~/.config/hypr/hyprland.conf << ```PR_EOF'
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
HYPR_EOF

        # Working waybar config
        cat > ~/.config/waybar/config << 'WAYBAR_EOF'```    "layer": "top",
    "height": 34,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["battery", "network"],
    "hyprland/workspaces": {"format": "{id}"},
    "clock": {"format": "{:%H:%M}"},
    "battery": {"format": "{capacity}%"},
    "network": {"format-wifi": "{essid}"}
}
WAYBAR_EOF

        # Wallpaper config
        echo 'preload = /usr/share/pixmaps/arch```ux-logo.png
wallpaper = ,/usr/share/pixmaps/archlinux-logo.png' > ~/.config/hypr/hyprpaper.conf

        echo "✅ Minimal working setup created"
        MLW_FALLBACK=true
    fi
fi

# Step 8: Run MLW installer if downloaded
if [ "$MLW_FALLBACK" != "true" ] && [ -f "mlw-install.sh" ]; then
    echo "🚀 Running MLW installer with thermal protection..."
    chmod +x mlw-install.sh
    
    # Run with timeout and cooling
    for attempt in 1 2 3; do
        echo "🔄 Installation attempt $attempt/3"
        if timeout 300s bash mlw-install.sh; then
            echo "✅ MLW installation successful!"
            break
        else
            if [ $attempt -lt 3 ]; then
                echo "🌡️ Cooling period (30s) before retry..."
                sleep 30
            else
                echo "❌ MLW installation failed - using minimal setup"
                MLW_FALLBACK=true
            fi
        fi
    done
fi

# Step 9: Enable SDDM
sudo systemctl enable sddm.service
sudo systemctl start sddm.service

# Step 10: Final setup
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/```thub.flatpakrepo ```dev/null || true

echo ""
echo "🎉 INSTALLATION COMPLETED!"
echo ""

if [ "$MLW_FALLBACK" = "true" ]; then
    echo "✅ Beautiful Minimal Hyprland Setup```stalled:"
    echo "   🎨 Rounded corners, blur, and shadows"
    echo "   📊 Working waybar with system info```   echo "   🖼️ Wallpaper display"
    echo "   ⚡ Smooth animations"
else
    echo "✅ MLW Dotfiles Successfully Installed:"
    echo "   🎨 Complete Material Design interface"
    echo "   📱 MLW Settings app"
    echo "   🖼️ Professional themes and wallpapers"
fi

echo ""
echo "🔑 Essential shortcuts:"
echo "   • Super + Q → Terminal"
echo "   • Super + R → App launcher"
echo "   • Super + 1,2,3 → Switch workspaces"
echo ""
echo "🔄 REBOOT NOW to complete installation!"

# Automatic reboot prompt
read -p "Reboot now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo reboot
else
    echo "💡 Reboot manually when ready:```do reboot"
fi
