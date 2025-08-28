#!/bin/bash
set -e

echo "[*] Installing dependencies..."
sudo pacman -S --needed git qt6-base qt6-declarative qt6-svg qt6-quickcontrols2 qt6-wayland qt6-shadertools --noconfirm

echo "[*] Cloning Caelestia repo..."
mkdir -p ~/.config/quickshell
if [ ! -d ~/.config/quickshell/caelestia ]; then
  git clone https://github.com/caelestia-dots/shell ~/.config/quickshell/caelestia
else
  cd ~/.config/quickshell/caelestia && git pull
fi

echo "[*] Running setup.sh..."
cd ~/.config/quickshell/caelestia
chmod +x setup.sh
./setup.sh || echo "[!] setup.sh failed, check logs"

echo "[*] Done. Restart Hyprland and run: quickshell -c caelestia"