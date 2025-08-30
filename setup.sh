cat > ~/setup.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo -e "\n[ Caelestia Setup – fixed path + autostart ]\n"

# ----- packages you need -----
pkgs=(git curl unzip tar
      qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools
      hyprland kitty pipewire wireplumber wl-clipboard)

echo "[*] Installing packages..."
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

# ----- paths -----
SRC="$HOME/.cache/caelestia-src"
CFG="$HOME/.config/quickshell/caelestia"
BIN="$HOME/.local/bin"

mkdir -p "$SRC" "$CFG" "$BIN"

# ----- clone repos -----
echo "[*] Cloning Caelestia repos…"
[ ! -d "$SRC/caelestia" ] && git clone --depth=1 https://github.com/caelestia-dots/caelestia "$SRC/caelestia" || true
[ ! -d "$SRC/shell"     ] && git clone --depth=1 https://github.com/caelestia-dots/shell     "$SRC/shell"     || true

# ----- copy shell (puts shell.qml exactly where QuickShell expects) -----
echo "[*] Installing shell files to $CFG …"
rm -rf "$CFG"
mkdir -p "$CFG"
cp -r "$SRC/shell/"* "$CFG/"

# ----- launcher -----
echo "[*] Creating launcher…"
LAUNCH="$BIN/caelestia-shell"
cat > "$LAUNCH" <<'L'
#!/bin/bash
QML2_IMPORT_PATH="$HOME/.config/quickshell/caelestia/modules" \
exec quickshell -c "$HOME/.config/quickshell/caelestia/shell.qml"
L
chmod +x "$LAUNCH"

# make sure ~/.local/bin is on PATH for future shells
grep -q "$HOME/.local/bin" "$HOME/.profile" 2>/dev/null || echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.profile"

# ----- Hyprland autostart -----
echo "[*] Adding Hyprland exec-once (if missing)…"
mkdir -p "$HOME/.config/hypr"
CONF="$HOME/.config/hypr/hyprland.conf"
touch "$CONF"
grep -q 'caelestia-shell' "$CONF" || echo 'exec-once = caelestia-shell' >> "$CONF"

# ----- sanity check -----
echo "[*] Verifying install…"
test -f "$CFG/shell.qml" || { echo "[x] shell.qml missing at $CFG/shell.qml"; exit 2; }
test -x "$LAUNCH"        || { echo "[x] launcher missing at $LAUNCH"; exit 3; }

echo -e "\n[✔] Caelestia installed."
echo "Use inside Hyprland (Wayland session):  caelestia-shell"
echo "It will also autostart next login."
EOF

chmod +x ~/setup.sh
~/setup.sh