cd ~/Arch  # or where your scripts are
cat > fix_quickshell.sh <<'EOF'
#!/usr/bin/env bash
set -e

echo "[*] Removing old quickshell package (if any)…"
yay -Rns --noconfirm quickshell || true

echo "[*] Installing build deps..."
sudo pacman -S --needed --noconfirm base-devel git cmake ninja \
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools

echo "[*] Cloning Quickshell upstream source…"
rm -rf ~/quickshell-src
git clone https://git.outfoxxed.me/quickshell/quickshell.git ~/quickshell-src

echo "[*] Building Quickshell…"
cd ~/quickshell-src
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release .
cmake --build build

echo "[*] Installing Quickshell…"
sudo cmake --install build

echo "[✔] Quickshell rebuilt successfully!"
echo "Now retry:  caelestia-shell"
EOF

chmod +x fix_quickshell.sh
./fix_quickshell.sh