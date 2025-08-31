#!/bin/bash
set -e

echo "[*] Removing old QuickShell..."
yay -Rns --noconfirm quickshell || true

echo "[*] Installing build dependencies..."
sudo pacman -S --needed --noconfirm base-devel git cmake ninja qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools

echo "[*] Cloning QuickShell source..."
rm -rf ~/quickshell-src
git clone https://github.com/Quaqqer/quickshell.git ~/quickshell-src

echo "[*] Building QuickShell..."
cd ~/quickshell-src
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

echo "[*] Installing QuickShell..."
sudo cmake --install build

echo "[*] Done. Now retry launching Caelestia:"
echo "     caelesia-shell"