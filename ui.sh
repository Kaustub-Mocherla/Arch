cat > ~/hypr_repair.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFGDIR="$HOME/.config/hypr"
WPDIR="$HOME/.config/wallpapers"
BACKUP="$HOME/.config/hypr.BAK.$(date +%F_%H%M%S)"

mkdir -p "$CFGDIR" "$WPDIR"

# Keep any existing config safe
if [ -e "$CFGDIR/hyprland.conf" ]; then
  mkdir -p "$BACKUP"
  cp -a "$CFGDIR"/* "$BACKUP"/
fi

# Ensure there is at least one wallpaper image
if ! ls "$WPDIR"/* >/dev/null 2>&1; then
  if ! command -v convert >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm imagemagick
  fi
  convert -size 1920x1080 gradient:'#1f1f28-#24283b' "$WPDIR/repair-fallback.png"
fi
WP="$(ls -1 "$WPDIR"/* | head -n1)"

# Minimal, robust Hyprland config
cat > "$CFGDIR/hyprland.conf" <<MINCONF
# === Minimal rescue config ===
monitor=,preferred,auto,1

# Sometimes avoids black cursor/screen on some iGPUs
env = WLR_NO_HARDWARE_CURSORS,1

input {
  kb_layout = us
}

general {
  gaps_in = 5
  gaps_out = 10
  border_size = 2
}

# Always give us a terminal + bar
exec-once = waybar
exec-once = mako
# wallpaper via swww if present, otherwise hyprpaper
exec-once = sh -c 'if command -v swww >/dev/null; then swww init && swww img "$WP"; else pkill -x hyprpaper >/dev/null 2>&1; echo -e "preload = $WP\nwallpaper = ,$WP\nsplash = false" > "$HOME/.config/hypr/hyprpaper.conf"; hyprpaper & fi'

# Basic binds
bind = SUPER, RETURN, exec, kitty
bind = SUPER, Q, killactive
bind = SUPER, C, exec, wofi --show drun
bind = SUPER, R, exec, hyprctl reload

# Window rules kept simple
decoration { rounding = 6 }
MINCONF

# Ensure SDDM has a Hyprland session
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'DESK'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
DESK

echo "Backed up old config to: $BACKUP"
echo "Wrote minimal config to: $CFGDIR/hyprland.conf"
EOF
bash ~/hypr_repair.sh