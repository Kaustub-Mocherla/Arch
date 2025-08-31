bash -euo pipefail <<'EOF'
echo "=== Caelestia: fix services/modules + fonts + launcher ==="

# --- paths
CE_DIR="$HOME/.config/quickshell/caelestia"
BIN="$HOME/.local/bin"
SYS_QML="/usr/lib/qt6/qml"               # Arch Qt6 QML base dir
CACHE="$HOME/.cache/caelestia-src"

mkdir -p "$BIN" "$CACHE"

# --- 1) Arch repo deps (no AUR here; you already have quickshell-git & caelestia-cli)
echo "[1/6] Installing runtime packages (pacman)…"
sudo pacman -Sy --needed --noconfirm \
  git cmake ninja \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  ddcutil brightnessctl app2unit cava networkmanager lm_sensors \
  fish aubio pipewire libqalculate bash curl unzip noto-fonts ttf-liberation

# --- 2) Fonts used by Caelestia (Material Symbols + Caskaydia NF) ---
echo "[2/6] Installing fonts (Material Symbols Rounded + Caskaydia NF)…"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
mkdir -p "$FONT_DIR"
# (a) Material Symbols Rounded variable TTF (official repo file)
MS_TTF="MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
MS_URL="https://github.com/google/material-design-icons/raw/master/variablefont/${MS_TTF}"
curl -fL --retry 3 -o "$FONT_DIR/$MS_TTF" "$MS_URL" || echo "!! Could not fetch Material Symbols (continuing)"
# (b) CaskaydiaCove Nerd Font (small subset, regular)
if ! ls "$FONT_DIR"/Caskaydia* >/dev/null 2>&1; then
  NF_TMP="$(mktemp -d)"
  NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
  echo "…downloading Caskaydia NF (CascadiaCode.zip)…"
  curl -fL --retry 3 -o "$NF_TMP/Caskaydia.zip" "$NF_URL" && unzip -o "$NF_TMP/Caskaydia.zip" -d "$NF_TMP" >/dev/null 2>&1 || true
  # install a couple of weights to keep it light
  find "$NF_TMP" -maxdepth 1 -type f -iname "Caskaydia*.ttf" | head -n 6 | while read -r f; do install -m 0644 "$f" "$FONT_DIR/"; done
  rm -rf "$NF_TMP"
fi
fc-cache -f "$FONT_DIR" >/dev/null || true

# --- 3) Get Caelestia shell sources (repo contains components/services/config/utils) ---
echo "[3/6] Syncing caelestia-dots/shell…"
if [ -d "$CACHE/shell/.git" ]; then
  git -C "$CACHE/shell" fetch --all -p
  git -C "$CACHE/shell" reset --hard origin/main
else
  git clone https://github.com/caelestia-dots/shell "$CACHE/shell"
fi

# --- 4) Build + install like the README (INSTALL_QSCONFDIR -> your CE_DIR) ---
echo "[4/6] Building & installing Caelestia shell to $CE_DIR …"
mkdir -p "$CE_DIR"
cd "$CACHE/shell"
rm -rf build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$CE_DIR"
cmake --build build
sudo cmake --install build
sudo chown -R "$USER:$USER" "$CE_DIR"

# --- 5) Launcher: ensure QML2_IMPORT_PATH includes your modules + system QML ---
echo "[5/6] Writing launcher $BIN/caelestia-shell …"
cat > "$BIN/caelestia-shell" <<LAU
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="\$HOME/.config/quickshell/caelestia"
# Put Caelestia's local modules first; also include system Qt6 QML dir so the Caelestia plugin is always found
export QML2_IMPORT_PATH="\$CE_DIR/modules:$SYS_QML\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=wayland
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "\$CE_DIR"
fi
LAU
chmod +x "$BIN/caelestia-shell"

# --- 6) Quality-of-life bits (don’t change your settings) ---
echo "[6/6] QoL: wallpapers folder + optional first wallpaper + ~/.face placeholder"
mkdir -p "$HOME/Pictures/Wallpapers"
# create ~/.face if missing so dashboard doesn’t warn
[ -f "$HOME/.face" ] || convert -size 256x256 xc:#444 "$HOME/.face" 2>/dev/null || true

# --- Diagnostics: prove the modules are present & importable ---
echo
echo "== Diagnostics =="
echo "QML plugin (system):   $SYS_QML/Caelestia (should exist after install)"
ls -1 "$SYS_QML"/Caelestia 2>/dev/null | sed 's/^/  - /' || echo "  !! Caelestia QML plugin directory not found (unexpected)"
echo
echo "Local modules (config): $CE_DIR/modules/qs (should have components/config/services/utils)"
ls -1 "$CE_DIR/modules/qs" 2>/dev/null | sed 's/^/  - /' || echo "  !! $CE_DIR/modules/qs missing"
echo
echo "Launcher is at: $BIN/caelestia-shell"
echo "You can now run:  caelestia-shell"
echo
EOF