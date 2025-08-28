#!/usr/bin/env bash
set -Eeuo pipefail

LOG="$HOME/caelestia_install.log"
exec > >(tee -a "$LOG") 2>&1

echo "[*] Installing Caelestia Shell..."

# -------------------------------
# Install dependencies
# -------------------------------
sudo pacman -Syy --noconfirm
sudo pacman -S --noconfirm --needed \
  git curl unzip tar \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
  pipewire wireplumber hyprland kitty

# QuickShell install
if ! command -v quickshell >/dev/null 2>&1; then
  echo "[*] Installing QuickShell..."
  if ! sudo pacman -S --noconfirm quickshell; then
    sudo pacman -S --noconfirm --needed base-devel
    git clone --depth=1 https://aur.archlinux.org/quickshell-git.git /tmp/quickshell-git
    (cd /tmp/quickshell-git && makepkg -si --noconfirm)
  fi
fi

# -------------------------------
# Fetch Caelestia Shell
# -------------------------------
CELE_DIR="$HOME/.config/quickshell/caelestia"
MOD_DIR="$CELE_DIR/modules"

rm -rf "$CELE_DIR"
mkdir -p "$CELE_DIR"

echo "[*] Downloading Caelestia Shell..."
curl -L https://github.com/caelestia-dots/shell/archive/refs/heads/main.tar.gz \
  | tar -xz -C "$CELE_DIR" --strip-components=1

# -------------------------------
# Fetch Caelestia Modules
# -------------------------------
rm -rf "$MOD_DIR"
mkdir -p "$MOD_DIR"

echo "[*] Downloading Caelestia Modules..."
curl -L https://github.com/caelestia-dots/modules/archive/refs/heads/main.tar.gz \
  | tar -xz -C "$MOD_DIR" --strip-components=1

# -------------------------------
# Autostart in Hyprland
# -------------------------------
HYPR_DIR="$HOME/.config/hypr"
HYPR_USER_CONF="$HYPR_DIR/hypr-user.conf"
mkdir -p "$HYPR_DIR"
touch "$HYPR_USER_CONF"

sed -i '/quickshell -c caelestia/d' "$HYPR_USER_CONF" || true
echo 'exec-once = quickshell -c caelestia' >> "$HYPR_USER_CONF"

# -------------------------------
# Helper command
# -------------------------------
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'EOF'
#!/usr/bin/env bash
exec quickshell -c caelestia
EOF
chmod +x "$HOME/.local/bin/caelestia-shell"

echo
echo "[✔] Caelestia installed successfully!"
echo "    - Logs: $LOG"
echo "    - To start manually: quickshell -c caelestia"
echo "    - Or just re-login into Hyprland (Caelestia autostarts)."