#!/usr/bin/env bash
# FixCaelestia.sh — fill missing configs, icons, and services Caelestia expects
# Usage:  bash FixCaelestia.sh
set -euo pipefail

echo "== Caelestia quick-fix: configs • wallpaper • icons • services =="

# --- paths
HOME_DIR="$HOME"
CFG_JSON_DIR="$HOME_DIR/.config/caelestia"
STATE_DIR="$HOME_DIR/.local/state/caelestia"
WP_DIR="$STATE_DIR/wallpaper"
WP_PATH_FILE="$WP_DIR/path.txt"
SCHEME_FILE="$STATE_DIR/scheme.json"
FACE_FILE="$HOME_DIR/.face"

# --- 1) Packages you’re missing for the warnings in your screenshot
echo "[1/5] Installing/ensuring required packages are present (repo pkgs)…"
sudo pacman -Sy --needed --noconfirm \
  papirus-icon-theme \
  bluez bluez-utils \
  power-profiles-daemon \
  swww jq curl unzip wl-clipboard grim slurp swappy \
  playerctl pamixer brightnessctl \
  noto-fonts ttf-liberation ttf-cascadia-code-nerd || true

# --- 2) Enable runtime services (Bluetooth + Power Profiles)
echo "[2/5] Enabling services…"
sudo systemctl enable --now bluetooth.service || true
sudo systemctl enable --now power-profiles-daemon.service || true

# --- 3) Create minimal config/state files Caelestia reads at startup
echo "[3/5] Creating minimal config/state files…"
mkdir -p "$CFG_JSON_DIR" "$WP_DIR"

# shell.json (used by @config/Config.qml)
if [ ! -s "$CFG_JSON_DIR/shell.json" ]; then
  cat > "$CFG_JSON_DIR/shell.json" <<'JSON'
{
  "wallpaper": {},
  "theme": {},
  "panels": {}
}
JSON
  echo "  • wrote $CFG_JSON_DIR/shell.json"
fi

# scheme.json (used by @services/Colours.qml)
if [ ! -s "$SCHEME_FILE" ]; then
  cat > "$SCHEME_FILE" <<'JSON'
{
  "accent": "#ff4081",
  "background": "#101010",
  "foreground": "#eaeaea"
}
JSON
  echo "  • wrote $SCHEME_FILE"
fi

# .face (avatar lookup — harmless if empty)
if [ ! -e "$FACE_FILE" ]; then
  touch "$FACE_FILE"
  echo "  • touched $FACE_FILE"
fi

# --- 4) Wallpaper: remember a path + optionally set one right now
echo "[4/5] Wallpaper setup…"
choose_wall() {
  # Find any image the user already has
  find "$HOME_DIR/Pictures/Wallpapers" "$HOME_DIR/Pictures" "$HOME_DIR" \
    -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null \
    | head -n1
}
if [ ! -s "$WP_PATH_FILE" ]; then
  SEL="$(choose_wall || true)"
  if [ -n "${SEL:-}" ]; then
    echo "$SEL" > "$WP_PATH_FILE"
    echo "  • saved wallpaper path: $SEL"
  else
    # create placeholder path entry; UI will still prompt you to set it
    echo "$HOME_DIR/Pictures/wallpaper.png" > "$WP_PATH_FILE"
    echo "  • no image found; placeholder saved to $WP_PATH_FILE"
  fi
fi

# Start swww daemon if not running, and set image if the file exists
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init || true
fi
if [ -s "$WP_PATH_FILE" ] && [ -f "$(cat "$WP_PATH_FILE" 2>/dev/null || echo '')" ]; then
  swww img "$(cat "$WP_PATH_FILE")" --transition-type any || true
fi

# --- 5) Icon theme (resolves “fallback-image-missing” for network icons)
echo "[5/5] Ensuring icon theme is available…"
# Just installing Papirus is usually enough; nothing else to do here.

echo
echo "✓ All done."
echo "If Caelestia is already open, press Super+Shift+R (or restart the shell)."
echo "To launch manually:  caelestia-shell"