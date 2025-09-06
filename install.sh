cat > ~/caelestia_ui_fix.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# 1) Correct Waybar config (clock format + sane defaults)
mkdir -p ~/.config/waybar
tee ~/.config/waybar/config.jsonc >/dev/null <<'JSON'
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "modules-left": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery", "tray"],
  "clock": {
    "format": "{:%a %d %b %H:%M}"
  },
  "pulseaudio": { "format": "{volume}%"},
  "network": { "format-wifi": "{essid} {signalStrength}%"},
  "battery": { "bat": "BAT0", "format": "{capacity}%"}
}
JSON

tee ~/.config/waybar/style.css >/dev/null <<'CSS'
* { font-family: JetBrainsMono, Noto Sans, FontAwesome; font-size: 12px; }
window#waybar { background: rgba(22,22,28,0.88); color: #ddd; }
#battery.critical { color: #e06c75; }
CSS

# 2) Ensure we always have a wallpaper
mkdir -p ~/.config/wallpapers
if ! ls ~/.config/wallpapers/* >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#1f1f28-#24283b' ~/.config/wallpapers/caelestia-fallback.png
fi
WALLPAPER="$(ls -1 ~/.config/wallpapers/* | head -n1)"

# Try swww first; fall back to hyprpaper
if command -v swww >/dev/null 2>&1; then
  swww init 2>/dev/null || true
  swww img "$WALLPAPER" --transition-type none 2>/dev/null || true
else
  mkdir -p ~/.config/hypr
  tee ~/.config/hypr/hyprpaper.conf >/dev/null <<HP
preload = $WALLPAPER
wallpaper = ,$WALLPAPER
splash = false
HP
  pkill -x hyprpaper 2>/dev/null || true
  hyprpaper &
fi

# 3) (Re)start Waybar cleanly
pkill -x waybar 2>/dev/null || true
waybar >/dev/null 2>&1 & disown

# 4) Make sure our Hyprland keybinds exist (kitty + launcher)
mkdir -p ~/.config/hypr
if ! grep -q 'bind = SUPER, RETURN, exec, kitty' ~/.config/hypr/99-rescue.conf 2>/dev/null; then
  tee -a ~/.config/hypr/99-rescue.conf >/dev/null <<'HYPR'
bind = SUPER, RETURN, exec, kitty
bind = SUPER, D, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, R, exec, hyprctl reload
HYPR
  # Ensure rescue config is sourced
  if [ -f ~/.config/hypr/hyprland.conf ] && ! grep -q 'source = .*99-rescue.conf' ~/.config/hypr/hyprland.conf; then
    echo 'source = $HOME/.config/hypr/99-rescue.conf' >> ~/.config/hypr/hyprland.conf
  fi
fi

echo "UI patch applied. If you don't see the bar/wallpaper, run: hyprctl reload"
SH

bash ~/caelestia_ui_fix.sh