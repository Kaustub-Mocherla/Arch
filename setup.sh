#!/usr/bin/env bash
set -euo pipefail

echo "=== Caelestia one-shot fix: repos + shell + qs.* modules + launcher ==="

# Paths
HOME_DIR="$HOME"
CFG_DIR="$HOME_DIR/.config/quickshell/caelestia"
MOD_DIR="$CFG_DIR/modules"
QS_MOD_DIR="$MOD_DIR/qs"                    # <-- where qs.* lives for QML imports
CACHE_DIR="$HOME_DIR/.cache/caelestia-src"
LAUNCHER="$HOME_DIR/.local/bin/caelestia-shell"

mkdir -p "$CFG_DIR" "$MOD_DIR" "$QS_MOD_DIR" "$CACHE_DIR" "$(dirname "$LAUNCHER")"

# 0) Light dependency check (no reflector/mirror changes to avoid more timeouts)
echo "[0/6] Verifying minimal run-time deps are present…"
sudo pacman -Sy --needed --noconfirm \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  swww wl-clipboard grim slurp swappy playerctl pamixer jq unzip curl || true

# 1) Pull/refresh Caelestia MAIN (building blocks) + SHELL
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

# 2) Install shell.qml + shell modules
echo "[2/6] Installing shell files…"
install -m 0644 "$CACHE_DIR/shell/shell.qml" "$CFG_DIR/shell.qml"
# rsync keeps structure and updates; no --delete to avoid nuking user tweaks
rsync -a "$CACHE_DIR/shell/modules/" "$MOD_DIR/"

# 3) Install the **qs.* module tree** so imports like `import qs.services` resolve
#    The main repo has subfolders we mirror under modules/qs/
echo "[3/6] Installing qs.* building-block modules…"
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

# 4) Write launcher with correct QML2_IMPORT_PATH
echo "[4/6] Writing launcher…"
cat > "$LAUNCHER" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
# Put Caelestia's modules (including qs/*) first on the QML import path
if [[ -n "${QML2_IMPORT_PATH:-}" ]]; then
  export QML2_IMPORT_PATH="$CE_DIR/modules:$QML2_IMPORT_PATH"
else
  export QML2_IMPORT_PATH="$CE_DIR/modules"
fi
export QT_QPA_PLATFORM=wayland
# Prefer caelestia CLI if present; otherwise run quickshell directly
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
LAU
chmod +x "$LAUNCHER"

# 5) Optional: start swww and set a first wallpaper if one exists
echo "[5/6] Wallpaper helper (optional)…"
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init || true
fi
first_img=""
for d in "$HOME_DIR/Pictures/Wallpapers" "$HOME_DIR/Pictures" "$HOME_DIR"; do
  first_img="$(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -n1 || true)"
  [[ -n "$first_img" ]] && break
done
if [[ -n "$first_img" ]]; then
  swww img "$first_img" --transition-type any || true
fi

# 6) Quick sanity prints
echo "[6/6] Verifying installed trees…"
echo "   • Shell config: $CFG_DIR/shell.qml"
echo "   • Shell modules: $MOD_DIR (e.g., background, bar, drawers, …)"
echo "   • QS modules:   $QS_MOD_DIR/{components,config,services,utils}"
echo
echo "Try now (inside Hyprland/Wayland):"
echo "   caelestia-shell"
echo
echo "If you still see 'module qs.services not installed', show me:"
echo "   ls -la $QS_MOD_DIR && find $QS_MOD_DIR -maxdepth 2 -type d | sort"