#!/usr/bin/env bash
set -euo pipefail

# === 0) Preconditions (Arch / not root) ===
if ! command_v() { command -v "$1" >/dev/null 2>&1; }; then true; fi
if ! command_v pacman; then echo "This script is for Arch-based systems."; exit 1; fi
if [[ $EUID -eq 0 ]]; then echo "Run as normal user (script uses sudo)."; exit 1; fi

# === 1) Full system update (video does this early) ===
sudo pacman -Syu --noconfirm

# === 2) Install SDDM (video installs & enables it) ===
sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm

# === 3) Install Hyprland + the components used in the video/caelestia ===
sudo pacman -S --needed --noconfirm \
  hyprland hyprpaper swww waybar wofi mako kitty thunar \
  pipewire pipewire-pulse wireplumber \
  xdg-desktop-portal-hyprland wl-clipboard \
  qt5-wayland qt6-wayland \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  gvfs gvfs-mtp gvfs-smb \
  brightnessctl playerctl \
  git fish starship \
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols

# === 4) Ensure Hyprland session entry for SDDM (video logs in via SDDM -> Hyprland) ===
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

# === 5) Enable core services (video uses networking, BT) ===
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth || true

# === 6) Get Caelestia shell and run its installer (video runs install.fish) ===
rm -rf "$HOME/caelestia-shell"
git clone https://github.com/caelestia-dots/shell "$HOME/caelestia-shell"
cd "$HOME/caelestia-shell"
fish ./install.fish

# === 7) Final touches ===
sudo chown -R "$USER:$USER" "$HOME"
chmod 700 "$HOME"

echo
echo "============================================================"
echo "Done (as per the video)."
echo "• Reboot now:  sudo reboot"
echo "• At SDDM, pick the 'Hyprland' session and log in."
echo "You should see Caelestia-shell."
echo "============================================================"