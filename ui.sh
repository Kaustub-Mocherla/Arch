#!/usr/bin/env bash
set -euo pipefail

# --- 0) Basic paths
HYPR_DIR="$HOME/.config/hypr"
AUTOSTART="$HYPR_DIR/autostart.conf"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

echo "[1/5] Ensure swww is installed…"
if ! command -v swww >/dev/null 2>&1; then
  echo "  -> Installing swww (sudo needed)…"
  sudo pacman -Sy --needed --noconfirm swww || {
    echo "!! Could not install swww. Install it manually and re-run."
    exit 1
  }
else
  echo "  ✓ swww already installed."
fi

echo "[2/5] Pick a wallpaper image…"
# Try to find an existing image in common places
pick_image() {
  for d in "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME/Downloads" "/usr/share/backgrounds" "/usr/share/pixmaps"; do
    [ -d "$d" ] || continue
    # Prioritize PNG/JPG
    f="$(find "$d" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -n1 || true)"
    [ -n "${f:-}" ] && { echo "$f"; return 0; }
  done
  echo ""  # none found
}

IMG="$(pick_image)"
if [ -n "$IMG" ]; then
  echo "  ✓ Found wallpaper: $IMG"
else
  echo "  ⚠ No image found in common folders."
  echo "    You can put a file in ~/Pictures and re-run:"
  echo "      swww img ~/Pictures/yourwallpaper.png --transition-type any"
fi

echo "[3/5] Start swww-daemon now (if not running)…"
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww-daemon >/dev/null 2>&1 &
  # give it a moment to create its socket
  sleep 1
  echo "  ✓ swww-daemon started."
else
  echo "  ✓ swww-daemon already running."
fi

if [ -n "$IMG" ]; then
  echo "[4/5] Apply wallpaper now…"
  # Try a gentle transition; ignore errors (e.g., if already set)
  swww img "$IMG" --transition-type any || true
  echo "  ✓ Wallpaper applied."
else
  echo "[4/5] Skipping apply step (no image yet)."
fi

echo "[5/5] Add Hyprland autostart (idempotent)…"
mkdir -p "$HYPR_DIR"

# Ensure hyprland.conf sources our autostart file (add only once)
if [ -f "$HYPR_CONF" ]; then
  if ! grep -qE '^\s*source\s*=\s*~/.config/hypr/autostart\.conf\s*$' "$HYPR_CONF"; then
    echo "source = ~/.config/hypr/autostart.conf" >> "$HYPR_CONF"
    echo "  ✓ Added 'source = ~/.config/hypr/autostart.conf' to hyprland.conf"
  else
    echo "  ✓ hyprland.conf already sources autostart.conf"
  fi
else
  # Create a minimal hyprland.conf that sources autostart
  echo "source = ~/.config/hypr/autostart.conf" > "$HYPR_CONF"
  echo "  ✓ Created hyprland.conf and sourced autostart.conf"
fi

# Write/update autostart.conf without duplicating entries
touch "$AUTOSTART"
add_exec_once() {
  local line="$1"
  if ! grep -qF "$line" "$AUTOSTART"; then
    echo "$line" >> "$AUTOSTART"
  fi
}

add_exec_once "exec-once = swww-daemon"
if [ -n "$IMG" ]; then
  # escape spaces
  esc_img="${IMG// /\\ }"
  add_exec_once "exec-once = swww img $esc_img --transition-type any"
fi

echo
echo "✓ Done."
echo "• Autostart file: $AUTOSTART"
echo "• If you change wallpapers later, just run:"
echo "    swww img /path/to/new.png --transition-type any"
echo "• If the first wallpaper didn't show, try logging out/in once so Hyprland picks up autostart."