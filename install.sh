#!/usr/bin/env bash
# Fix blank Hyprland session: ensures autostart + minimal configs

set -euo pipefail
say(){ printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

PACKS=(
  hyprland xdg-desktop-portal-hyprland waybar wofi kitty mako
  hyprpaper swww-git wl-clipboard grimblast polkit-gnome
  network-manager-applet brightnessctl pipewire wireplumber
  qt6ct qt5ct noto-fonts ttf-jetbrains-mono ttf-font-awesome
)

say "Installing/repairing needed packages…"
sudo pacman -S --needed --noconfirm "${PACKS[@]}" || true
# if swww-git conflicts, remove the repo swww
sudo pacman -R --noconfirm swww 2>/dev/null || true

mkdir -p "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/wallpapers"

# fallback wallpaper if none exists
if [[ ! -f "$HOME/.config/wallpapers/caelestia-fallback.png" ]]; then
  command -v convert >/dev/null 2>&1 && \
    convert -size 1920x1080 xc:"#101216" "$HOME/.config/wallpapers/caelestia-fallback.png" \
    || cp /usr/share/backgrounds/* 2>/dev/null \
         "$HOME/.config/wallpapers/caelestia-fallback.png" 2>/dev/null || \
       touch "$HOME/.config/wallpapers/caelestia-fallback.png"
fi

# Minimal Waybar config (only if missing)
if [[ ! -s "$HOME/.config/waybar/config.jsonc" && ! -s "$HOME/.config/waybar/config" ]]; then
cat >"$HOME/.config/waybar/config.jsonc" <<'JSON'
{
  "layer": "top",
  "height": 30,
  "modules-left": ["clock"],
  "modules-center": [],
  "modules-right": ["network", "pulseaudio", "cpu", "memory", "temperature", "battery"],
  "network": {"format-wifi": "{essid} {signalStrength}%"},
  "temperature": {"critical-threshold": 90},
  "battery": {"format": "{capacity}%"}
}
JSON
fi
if [[ ! -s "$HOME/.config/waybar/style.css" ]]; then
cat >"$HOME/.config/waybar/style.css" <<'CSS'
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans"; font-size: 12px; }
window { background: rgba(16,18,22,0.6); color: #c8d3f5; }
CSS
fi

# Emergency Hypr config that *always* autostarts essentials.
HYPR="$HOME/.config/hypr/hyprland.conf"
if [[ ! -s "$HYPR" ]]; then
  touch "$HYPR"
fi

# write/replace an [Autostart] block safely
awk '
/^# --- AUTOSTART BEGIN ---/{flag=1}
/^# --- AUTOSTART END ---/{flag=0;next}
flag{next} {print}
END{
print "# --- AUTOSTART BEGIN ---"
print "env = XDG_CURRENT_DESKTOP,Hyprland"
print "env = QT_QPA_PLATFORM,wayland"
print "env = GDK_BACKEND,wayland,x11"
print "exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
print "exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
print "exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
print "exec-once = nm-applet --indicator"
print "exec-once = mako"
print "exec-once = swww init"
print "exec-once = swww img ~/.config/wallpapers/caelestia-fallback.png"
print "exec-once = waybar"
print "# keybinds (in case Caelestia binds are missing)"
print "bind = SUPER, RETURN, exec, kitty"
print "bind = SUPER, D, exec, wofi --show drun"
print "bind = SUPER SHIFT, R, exec, hyprctl reload"
print "# --- AUTOSTART END ---"
}' "$HYPR" > "$HYPR.tmp" && mv "$HYPR.tmp" "$HYPR"

# make sure kitty exists as terminal
command -v kitty >/dev/null || sudo pacman -S --noconfirm kitty

# Reload if we are already in a Hyprland session; otherwise just exit
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  say "Reloading Hyprland…"
  hyprctl reload || true
fi

say "Done. Reboot, choose Hyprland in SDDM, log in."
echo "If you still see blank screen: press Super+Enter (kitty), then run:"
echo "  pkill waybar; waybar &"
echo "  swww init; swww img ~/.config/wallpapers/caelestia-fallback.png"