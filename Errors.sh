#!/usr/bin/env bash
set -euo pipefail

echo "=== Caelestia repair: repos + shell + qs modules + QML path + wallpaper ==="

# --- paths
HOME_DIR="$HOME"
CFG_DIR="$HOME_DIR/.config/quickshell/caelestia"
MOD_DIR="$CFG_DIR/modules"
QS_MOD_DIR="$MOD_DIR/qs"
CACHE_DIR="$HOME_DIR/.cache/caelestia-src"
LAUNCHER="$HOME_DIR/.local/bin/caelestia-shell"
SYS_QML_DIR="/usr/lib/qt6/qml"   # QuickShell ships its QMLs here on Arch

mkdir -p "$CFG_DIR" "$MOD_DIR" "$QS_MOD_DIR" "$CACHE_DIR" "$(dirname "$LAUNCHER")"

# --- 0) minimal runtime deps (do NOT touch mirrors)
echo "[0/6] Ensuring minimal deps exist (skipping if already present)…"
sudo pacman -Sy --needed --noconfirm \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  swww wl-clipboard grim slurp swappy playerctl pamixer jq curl unzip || true

# --- 1) clone/refresh repos
echo "[1/6] Syncing Caelestia sources…"
if [[ -d "$CACHE_DIR/caelestia/.git" ]]; then
  git -C "$CACHE_DIR/caelestia" fetch --all -p || true
  git -C "$CACHE_DIR/caelestia" reset --hard origin/main || true
else
  rm -rf "$CACHE_DIR/caelestia"
  git clone https://github.com/caelestia-dots/caelestia "$CACHE_DIR/caelestia"
fi

if [[ -d "$CACHE_DIR/shell/.git" ]]; then
  git -C "$CACHE_DIR/shell" fetch --all -p || true
  git -C "$CACHE_DIR/shell" reset --hard origin/main || true
else
  rm -rf "$CACHE_DIR/shell"
  git clone https://github.com/caelestia-dots/shell "$CACHE_DIR/shell"
fi

# --- 2) install shell files
echo "[2/6] Installing shell files…"
install -m 0644 "$CACHE_DIR/shell/shell.qml" "$CFG_DIR/shell.qml"
rsync -a "$CACHE_DIR/shell/modules/" "$MOD_DIR/"

# --- 3) provide qs/* modules (so 'import qs.services' etc. resolve)
echo "[3/6] Installing qs.* modules…"
for d in components services config utils; do
  SRC="$CACHE_DIR/caelestia/$d"
  DEST="$QS_MOD_DIR/$d"
  if [[ -d "$SRC" ]]; then
    mkdir -p "$DEST"
    rsync -a --delete "$SRC/" "$DEST/"
    echo "   - qs/$d ✓"
  else
    echo "   - WARNING: main repo missing '$d' (skipped)"
  fi
done

# --- 4) launcher: put Caelestia modules and system QML dir on the import path
echo "[4/6] Writing launcher…"
cat > "$LAUNCHER" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
SYS_QML_DIR="/usr/lib/qt6/qml"
if [[ -n "${QML2_IMPORT_PATH:-}" ]]; then
  export QML2_IMPORT_PATH="$CE_DIR/modules:$SYS_QML_DIR:$QML2_IMPORT_PATH"
else
  export QML2_IMPORT_PATH="$CE_DIR/modules:$SYS_QML_DIR"
fi
export QT_QPA_PLATFORM=wayland
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
LAU
chmod +x "$LAUNCHER"

# --- 5) optional: ensure swww daemon & try a first wallpaper
echo "[5/6] Wallpaper helper…"
if ! pgrep -x swww-daemon >/dev/null 2>&1; then swww init || true; fi
first_img=""
for d in "$HOME_DIR/Pictures/Wallpapers" "$HOME_DIR/Pictures" "$HOME_DIR"; do
  first_img="$(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -n1 || true)"
  [[ -n "$first_img" ]] && break
done
[[ -n "$first_img" ]] && swww img "$first_img" --transition-type any || true

# --- 6) sanity prints
echo "[6/6] Verifying:"
echo "  shell.qml     -> $CFG_DIR/shell.qml"
echo "  shell modules -> $MOD_DIR"
echo "  qs modules    -> $QS_MOD_DIR/{components,config,services,utils}"
echo
echo "Launch now (inside Hyprland):  caelestia-shell"
echo
echo "If anything still looks missing, show:"
echo "  ls -la $QS_MOD_DIR && find $QS_MOD_DIR -maxdepth 2 -type d | sort"