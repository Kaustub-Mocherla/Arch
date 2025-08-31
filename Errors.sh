bash -euo pipefail <<'EOS'
# === Caelestia shell (per README) + fonts + starter wallpaper ===

CE_DIR="$HOME/.config/quickshell/caelestia"
BIN="$HOME/.local/bin"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
WALL_DIR="$HOME/Pictures/Wallpapers"

echo "[1/6] Base runtime + build deps (repo)"
sudo pacman -Syu --needed --noconfirm \
  git base-devel cmake ninja \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  ddcutil brightnessctl app2unit cava networkmanager lm_sensors fish \
  aubio pipewire libqalculate bash \
  swww wl-clipboard grim slurp swappy playerctl pamixer \
  noto-fonts ttf-liberation ttf-cascadia-code-nerd curl unzip

echo "[2/6] Verify AUR bits the README expects"
if ! pacman -Q quickshell-git >/dev/null 2>&1; then
  echo "!! quickshell-git is NOT installed (AUR). Install it, then rerun this script."
  exit 1
fi
if ! pacman -Q caelestia-cli >/dev/null 2>&1; then
  echo "!! caelestia-cli is NOT installed (AUR). Install it, then rerun this script."
  exit 1
fi

echo "[3/6] Fonts: Material Symbols Rounded (variable TTF)"
mkdir -p "$FONT_DIR"
tmp="$(mktemp -d)"
# official variable font from google/material-design-icons
name="MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
url="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
curl -fsSL "$url" -o "$tmp/$name"
if [ -s "$tmp/$name" ]; then
  install -m0644 "$tmp/$name" "$FONT_DIR/$name"
  fc-cache -f "$FONT_DIR" >/dev/null || true
  echo "  ok: Material Symbols installed to $FONT_DIR"
else
  echo "  warn: could not fetch Material Symbols (network?), continuing…"
fi
rm -rf "$tmp"

echo "[4/6] Clone/update Caelestia shell to \$XDG_CONFIG_HOME/quickshell/caelestia"
mkdir -p "$CE_DIR"
if [ -d "$CE_DIR/.git" ]; then
  git -C "$CE_DIR" fetch --all --prune
  git -C "$CE_DIR" reset --hard origin/main
else
  rm -rf "$CE_DIR"
  git clone https://github.com/caelestia-dots/shell.git "$CE_DIR"
fi

echo "[5/6] Build + install (README manual install)"
cd "$CE_DIR"
rm -rf build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$CE_DIR"
cmake --build build
sudo cmake --install build
sudo chown -R "$USER:$USER" "$CE_DIR"

# Launcher (prefers official CLI like the README Usage section)
mkdir -p "$BIN"
cat > "$BIN/caelestia-shell" <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
# QuickShell plugins are in /usr/lib/qt6/qml after install; no custom path needed.
export QT_QPA_PLATFORM=wayland
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
LAUNCH
chmod +x "$BIN/caelestia-shell"

echo "[6/6] Starter wallpaper so the shell stops nagging"
mkdir -p "$WALL_DIR"
# tiny public placeholder (replace later with your own)
curl -fsSL "https://picsum.photos/1920/1080" -o "$WALL_DIR/caelestia-placeholder.jpg" || true

# Try to set wallpaper via CLI if available; otherwise swww as fallback
if command -v caelestia >/dev/null 2>&1; then
  caelestia wallpaper set "$WALL_DIR/caelestia-placeholder.jpg" || true
else
  if ! pgrep -x swww-daemon >/dev/null 2>&1; then swww init || true; fi
  swww img "$WALL_DIR/caelestia-placeholder.jpg" --transition-type any || true
fi

echo
echo "✓ Done."
echo "Run the shell (inside Hyprland):  caelestia-shell"
echo
echo "Tip: wallpapers are read from $WALL_DIR (per README)."
echo "     Profile picture (dashboard) uses ~/.face (per README)."
EOS