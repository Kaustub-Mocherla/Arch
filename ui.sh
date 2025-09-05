#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }
line(){ grep -Fqx "$1" "$CFG" || echo "$1" >> "$CFG"; }

CFG="$HOME/.config/hypr/hyprland.conf"
CFGDIR="$HOME/.config/hypr"
WPD="$HOME/.config/wallpapers"
mkdir -p "$CFGDIR" "$WPD"

# Make sure we have at least one image
if ! ls "$WPD"/* >/dev/null 2>&1; then
  echo "Creating fallback wallpaper…"
  command -v convert >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm imagemagick
  convert -size 1920x1080 gradient:'#1f1f28-#24283b' "$WPD/caelestia.png"
fi
WP_IMG="$(ls -1 "$WPD"/* | head -n1)"

# Ensure a base hypr config exists
[[ -f "$CFG" ]] || cat > "$CFG" <<'EOF'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
EOF
cp -a "$CFG" "$CFG.backup.$(date +%Y%m%d-%H%M%S)"

# Remove duplicate/old autostarts
sed -i \
  -e '/^\s*exec-once\s*=\s*swww/d' \
  -e '/^\s*exec-once\s*=\s*hyprpaper/d' \
  -e '/^\s*exec-once\s*=\s*waybar/d' \
  -e '/^\s*exec-once\s*=\s*mako/d' \
  "$CFG"

# Prefer swww (with init). If not usable, set up hyprpaper.
USE="hyprpaper"
if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
  USE="swww"
fi

if [[ "$USE" = "swww" ]]; then
  line "exec-once = swww init"
  line "exec-once = swww img $WP_IMG"
else
  command -v hyprpaper >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm hyprpaper
  cat > "$CFGDIR/hyprpaper.conf" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash = false
EOF
  line "exec-once = hyprpaper &"
fi

# Ensure bar + notifications (single instance)
line "exec-once = waybar"
line "exec-once = mako"

# Apply now if we’re inside Hyprland
if have hyprctl && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  pkill -x waybar   >/dev/null 2>&1 || true
  pkill -x mako     >/dev/null 2>&1 || true
  pkill -x hyprpaper >/dev/null 2>&1 || true
  pkill -x swww-daemon >/dev/null 2>&1 || true

  if [[ "$USE" = "swww" ]]; then
    swww init || true
    swww img "$WP_IMG" || true
  else
    hyprpaper & disown
  fi

  waybar & disown
  mako & disown
  hyprctl reload -r || true
fi

echo "Done. Using: $USE  | Wallpaper: $WP_IMG"
echo "If you still see a blank background, run inside Hyprland:"
echo "  swww init && swww img \"$WP_IMG\"    (or just relogin)"