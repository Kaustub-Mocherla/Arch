#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing QuickShell from source (AUR replacement)…"

# Install build tools
sudo pacman -S --needed --noconfirm base-devel git cmake ninja qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools

# Remove any old source
rm -rf "$HOME/.cache/quickshell-src"
mkdir -p "$HOME/.cache"
cd "$HOME/.cache"

# Clone QuickShell
git clone --depth=1 https://github.com/queso-fondue/quickshell quickshell-src
cd quickshell-src

# Build QuickShell
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Install QuickShell system-wide
sudo cmake --install build

echo "[+] QuickShell installed successfully!"
echo "    Try running: quickshell --version"