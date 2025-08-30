#!/bin/bash
set -e

echo -e "\n[ Caelestia Setup Script - Fixed Version ]\n"

# Required packages (fixed: removed qt6-quickcontrols2, included declarative instead)
need_pkgs=(
  git curl unzip tar
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools
  hyprland kitty pipewire wireplumber wl-clipboard
)

echo "[*] Installing required packages..."
sudo pacman -Syu --needed --noconfirm "${need_pkgs[@]}"

# Base directories
SRC_DIR="$HOME/.cache/caelestia-src"
CONFIG_DIR="$HOME/.config/quickshell/caelestia"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$SRC_DIR" "$CONFIG_DIR" "$BIN_DIR"

echo "[*] Cloning repos..."
# Main Caelestia repo
if [ ! -d "$SRC_DIR/caelestia" ]; then
  git clone --depth=1 https://github.com/caelestia-dots/caelestia "$SRC_DIR/caelestia"
else
  echo "[=] Main repo already cloned."
fi

# Shell repo (UI config + modules)
if [ ! -d "$SRC_DIR/shell" ]; then
  git clone --depth=1 https://github.com/caelestia-dots/shell "$SRC_DIR/shell"
else
  echo "[=] Shell repo already cloned."
fi

echo "[*] Copying config & modules..."
rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
cp -r "$SRC_DIR/shell/"* "$CONFIG_DIR/"

# Create launcher
LAUNCHER="$BIN_DIR/caelestia-shell"
cat > "$LAUNCHER" <<EOF
#!/bin/bash
QML2_IMPORT_PATH=\$HOME/.config/quickshell/caelestia/modules \
exec quickshell -c \$HOME/.config/quickshell/caelestia/shell.qml
EOF
chmod +x "$LAUNCHER"

# Add to PATH if not already
if ! grep -q "$BIN_DIR" <<< "$PATH"; then
  echo "export PATH=\$PATH:$BIN_DIR" >> "$HOME/.profile"
fi

echo "[*] Setting Hyprland autostart..."
mkdir -p "$HOME/.config/hypr"
if ! grep -q "caelestia-shell" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null; then
  echo "exec-once = caelestia-shell" >> "$HOME/.config/hypr/hyprland.conf"
fi

echo -e "\n[✔] All done!"
echo "To start Caelestia now (inside Hyprland/Wayland):"
echo "   caelestia-shell"