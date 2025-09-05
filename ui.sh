#!/usr/bin/env bash
set -euo pipefail

# Must be run INSIDE Hyprland
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprctl >/dev/null 2>&1; then
  echo "Run this INSIDE your Hyprland session (open Kitty and run it there)."
  exit 1
fi

have(){ command -v "$1" >/dev/null 2>&1; }

CFGDIR="$HOME/.config/hypr"
CFG="$CFGDIR/hyprland.conf"
WPDIR="$HOME/.config/wallpapers"
mkdir -p "$CFGDIR" "$WPDIR"

# Ensure base config exists
if [[ ! -f "$CFG" ]]; then
  cat > "$CFG" <<'EOF'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
EOF
fi

# Ensure at least one wallpaper
if ! ls "$WPDIR"/* >/dev/null 2>&1; then
  if ! have convert; then
    echo "Installing imagemagick to create a fallback wallpaper (sudo needed)…"
    sudo pacman -S --needed --noconfirm imagemagick
  fi
  convert -size 1920x1080 gradient:'#1f1f28-#24283b' "$WPDIR/caelestia-fallback.png"
fi
WP_IMG="$(ls -1 "$WPDIR"/* | head -n1)"

# Choose backend: prefer swww (must support 'init'), else hyprpaper
BACKEND="hyprpaper"
if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
  BACKEND="swww"
fi

# Backup and clean duplicates
cp -a "$CFG" "$CFG.backup.$(date +%Y%m%d-%H%M%S)"
sed -i \
  -e '/^\s*exec-once\s*=\s*swww\b/d' \
  -e '/^\s*exec-once\s*=\s*hyprpaper\b/d' \
  -e '/^\s*exec-once\s*=\s*waybar\b/d' \
  -e '/^\s*exec-once\s*=\s*mako\b/d' \
  "$CFG"

# Write tidy autostart block
{
  echo
  echo "### === AUTOSTART (managed by hyprland_wallpaper_fix.sh) ==="
  if [[ "$BACKEND" == "swww" ]]; then
    echo "exec-once = swww init"
    echo "exec-once = swww img $WP_IMG"
  else
    cat > "$CFGDIR/hyprpaper.conf" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash   = false
EOF
    echo "exec-once = hyprpaper &"
  fi
  echo "exec-once = waybar"
  echo "exec-once = mako"
} >> "$CFG"

# Apply now
pkill -x waybar      >/dev/null 2>&1 || true
pkill -x mako        >/dev/null 2>&1 || true
pkill -x hyprpaper   >/dev/null 2>&1 || true
pkill -x swww-daemon >/dev/null 2>&1 || true

if [[ "$BACKEND" == "swww" ]]; then
  swww init || true
  swww img "$WP_IMG" || true
else
  hyprpaper & disown
fi
waybar & disown
mako & disown

hyprctl reload -r || true

echo "======================================="
echo "Done. Backend: $BACKEND"
echo "Wallpaper: $WP_IMG"
echo "Waybar + Mako started; config updated:"
echo "  $CFG"
echo "Backup created as $CFG.backup.*"
echo "Try: Super+Enter (Kitty), Super+Space (Wofi)"
echo "======================================="