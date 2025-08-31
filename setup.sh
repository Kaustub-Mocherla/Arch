#!/bin/bash
set -e

echo "[*] Cleaning old Caelestia configs..."
rm -rf ~/.config/quickshell/caelestia
rm -rf ~/.cache/caelestia-src
rm -rf ~/.local/bin/caelestia-shell

echo "[*] Installing dependencies..."
sudo pacman -Syu --needed --noconfirm git base-devel cmake ninja qt6-base qt6-svg qt6-declarative qt6-shadertools qt6-wayland unzip tar curl

# Ensure yay is present
if ! command -v yay >/dev/null 2>&1; then
    echo "[*] Installing yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
fi

echo "[*] Cloning Caelestia repos..."
mkdir -p ~/.cache/caelestia-src
cd ~/.cache/caelestia-src

# Clone main repo
if [ ! -d "caelestia" ]; then
    git clone https://github.com/caelestia-dots/caelestia.git
else
    echo "[=] Main repo already cloned."
fi

# Clone shell repo
if [ ! -d "shell" ]; then
    git clone https://github.com/caelestia-dots/shell.git
else
    echo "[=] Shell repo already cloned."
fi

echo "[*] Setting up Caelestia config..."
mkdir -p ~/.config/quickshell/caelestia
cp -r shell/shell.qml shell/modules ~/.config/quickshell/caelestia/

echo "[*] Creating launcher..."
mkdir -p ~/.local/bin
cat <<EOF > ~/.local/bin/caelestia-shell
#!/bin/bash
export QML2_IMPORT_PATH="\$HOME/.config/quickshell/caelestia/modules"
exec quickshell -c \$HOME/.config/quickshell/caelestia/shell.qml
EOF
chmod +x ~/.local/bin/caelestia-shell

# Add to PATH
if ! grep -q ".local/bin" ~/.profile; then
    echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.profile
fi

echo "[✔] Installation complete."
echo "---------------------------------------------------"
echo "Now reboot into Hyprland (Wayland)."
echo "Inside your kitty terminal, run:"
echo "    source ~/.profile"
echo "    caelestia-shell"
echo "---------------------------------------------------"