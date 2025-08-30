#!/bin/bash
set -e

echo -e "\n[ Caelestia Setup Script - FINAL FIXED VERSION ]\n"

# Packages
pkgs=(
  git curl unzip tar
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools
  hyprland kitty pipewire wireplumber wl-clipboard
)

echo "[*] Installing packages..."
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

# Directories
SRC="$HOME/.cache/caelestia-src"
CFG="$HOME/.config/quickshell/caelestia"
BIN="$HOME/.local/bin"

mkdir -p "$SRC" "$CFG" "$BIN"

echo "[*] Cloning repos..."
# Main
[ ! -d "$SRC/caelestia" ] && git clone --depth=1 https://github.com/caelestia-dots/caelestia "$SRC/caelestia"
# Shell
[ ! -d "$SRC/shell" ] && git clone --depth=1 https://github.com/caelestia-dots/shell "$SRC/shell"

echo "[*] Copying shell config..."
rm -rf "$CFG"
mkdir -p "$CFG"
cp -r "$SRC/shell/"* "$CFG/"

# Launcher
LAUNCH="$BIN/caelestia-shell"
cat > "$LAUNCH" <<EOF
#!/bin/bash
QML2_IMPORT_PATH=\$HOME/.config/quickshell/caelestia/modules \\
exec quickshell -c \$HOME/.config/quickshell/caelestia/shell.qml
EOF
chmod +x "$LAUNCH"

# Path
if ! grep -q "$BIN" <<< "$PATH"; then
  echo "export PATH=\$PATH:$BIN" >> "$HOME/.profile"
fi

# Hyprland autostart
mkdir -p "$HOME/.config/hypr"
if ! grep -q "caelestia-shell" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null; then
  echo "exec-once = caelestia-shell" >> "$HOME/.config/hypr/hyprland.conf"
fi

echo -e "\n[✔] All set!"
echo "Start inside Hyprland with:"
echo "   caelestia-shell"