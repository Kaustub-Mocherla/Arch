#!/usr/bin/env bash
set -euo pipefail

# ===== Caelestia clean install (after end-4), with swww-git fix + safe fallback =====

MAX_TEMP=85
CHECK_EVERY=10

END4_REPO="$HOME/dots-hyprland"
CAEL_REPO_URL="https://github.com/caelestia-dots/shell.git"
CAEL_REPO="$HOME/.local/share/caelestia"
CFG="$HOME/.config"
HYPR="$CFG/hypr"
WB="$CFG/waybar"
WOFI="$CFG/wofi"
KITTY="$CFG/kitty"
WPDIR="$CFG/wallpapers"
LOG="$HOME/caelestia_clean_install_$(date +%F_%H%M%S).log"

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
cpu_temp(){ sensors 2>/dev/null | awk '/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{for(i=1;i<=NF;i++) if($i~/[0-9]+(\.[0-9]+)?°C/){gsub(/[+°C]/,"",$i); print $i+0}}' | sort -nr | head -n1; }
cool_wait(){
  if ! have sensors; then sudo pacman -S --needed --noconfirm lm_sensors; fi
  local t="$(cpu_temp)"; t=${t:-0}
  echo "CPU temp: ${t}°C (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "…cooling (<= ${MAX_TEMP}°C to continue)"; sleep "$CHECK_EVERY"
    t="$(cpu_temp)"; t=${t:-0}; echo "  -> ${t}°C"
  done
}
pac(){ cool_wait; sudo pacman -S --needed --noconfirm "$@"; }

exec > >(tee -a "$LOG") 2>&1

say "Stopping possible Waybar/Wallpaper daemons…"
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
pkill -x swww 2>/dev/null || true
pkill -x mako 2>/dev/null || true

# --------------------------------------------------------------------
# 0) swww conflict guard (ALWAYS run first)
# --------------------------------------------------------------------
say "Checking for swww conflicts…"
if pacman -Qi swww &>/dev/null; then
  say "Removing stable swww (conflicts with swww-git)…"
  sudo pacman -Rns --noconfirm swww || true
fi

# --------------------------------------------------------------------
# 1) Clean end-4 leftovers
# --------------------------------------------------------------------
BACKUP="$HOME/.config_end4_cleanup_$(date +%F_%H%M%S)"
say "Backing up end-4 configs to: $BACKUP"
mkdir -p "$BACKUP"
for d in hypr waybar wofi kitty fish foot; do
  [[ -e "$CFG/$d" ]] && mv "$CFG/$d" "$BACKUP/" || true
done
[[ -d "$END4_REPO/.git" ]] && { say "Removing end-4 repo…"; rm -rf "$END4_REPO"; }

mkdir -p "$HYPR" "$WB" "$WOFI" "$KITTY" "$WPDIR"

# --------------------------------------------------------------------
# 2) Core runtime packages (no AUR here)
# --------------------------------------------------------------------
say "Installing core Wayland/Hyprland runtime…"
pac hyprland sddm fish git \
    waybar wofi kitty mako \
    hyprpaper wl-clipboard grim slurp jq \
    pipewire pipewire-pulse wireplumber polkit-gnome \
    xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome \
    imagemagick lm_sensors

say "Enable services…"
sudo systemctl enable --now sddm || true
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true

# --------------------------------------------------------------------
# 3) Prefer swww-git; install it if yay exists, else fallback to swww
# --------------------------------------------------------------------
if pacman -Qi swww-git &>/dev/null; then
  say "swww-git already installed."
else
  if have yay; then
    cool_wait
    say "Installing swww-git via yay (preferred by Caelestia)…"
    nice -n 19 ionice -c3 yay -S --needed --noconfirm swww-git
  else
    say "yay not found; installing stable swww to ensure wallpapers work."
    pac swww
  fi
fi

# --------------------------------------------------------------------
# 4) SDDM session fix
# --------------------------------------------------------------------
say "Ensuring SDDM uses dbus-run-session for Hyprland…"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

# --------------------------------------------------------------------
# 5) Clone & run Caelestia install.fish
# --------------------------------------------------------------------
say "Cloning/updating Caelestia-shell repo…"
mkdir -p "$(dirname "$CAEL_REPO")"
if [[ -d "$CAEL_REPO/.git" ]]; then
  git -C "$CAEL_REPO" pull --ff-only
else
  git clone "$CAEL_REPO_URL" "$CAEL_REPO"
fi

say "Running Caelestia install.fish…"
pac fish
cool_wait
fish -c "$CAEL_REPO/install.fish"

# --------------------------------------------------------------------
# 6) Bulletproof fallback (no blank screen)
# --------------------------------------------------------------------
say "Setting up rescue overlay…"
if ! ls "$WPDIR"/* >/dev/null 2>&1; then
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$WPDIR/caelestia-fallback.png"
fi
WP="$(ls -1 "$WPDIR"/* | head -n1)"

BAT="$(ls /sys/class/power_supply/ 2>/dev/null | grep '^BAT' | head -n1 || true)"
[[ -z "${BAT:-}" ]] && BAT="BAT0"

cat > "$WB/config.jsonc" <<EOF
{
  "layer":"top","position":"top","height":28,
  "modules-left":["clock"],
  "modules-right":["pulseaudio","network","battery","tray"],
  "clock":{"format":"%a %d %b %H:%M"},
  "pulseaudio":{"format":"{volume}%"},
  "network":{"format-wifi":"{essid} {signalStrength}%","format-ethernet":"{ifname}"},
  "battery":{"bat":"$BAT","format":"{capacity}%"}
}
EOF
cat > "$WB/style.css" <<'EOF'
* { font-family: JetBrainsMono, Noto Sans, FontAwesome; font-size: 12px; }
window#waybar { background: rgba(22,22,28,0.85); color: #ddd; }
#battery.critical { color: #e06c75; }
EOF

cat > "$WOFI/style.css" <<'EOF'
window { background-color: rgba(22,22,28,0.95); }
#input { padding: 6px; }
EOF

cat > "$KITTY/kitty.conf" <<'EOF'
font_family JetBrains Mono
font_size   11
enable_audio_bell no
EOF

cat > "$HYPR/autostart.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP DESKTOP_SESSION GTK_THEME QT_QPA_PLATFORMTHEME || true
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true

if command -v swww >/dev/null 2>&1; then
  swww init 2>/dev/null || true
  swww img "$WP" --transition-type none 2>/dev/null || true
else
  cat > "\$HOME/.config/hypr/hyprpaper.conf" <<HP
preload = $WP
wallpaper = ,$WP
splash = false
HP
  hyprpaper &
fi

waybar &
mako &
kitty &
EOF
chmod +x "$HYPR/autostart.sh"

OVERLAY="$HYPR/99-rescue.conf"
cat > "$OVERLAY" <<'EOF'
# === Caelestia Rescue Overlay ===
env = WLR_NO_HARDWARE_CURSORS,1
exec-once = $HOME/.config/hypr/autostart.sh
bind = SUPER, RETURN, exec, kitty
bind = SUPER, C, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, R, exec, hyprctl reload
EOF

if [[ -f "$HYPR/hyprland.conf" ]]; then
  grep -q '99-rescue.conf' "$HYPR/hyprland.conf" || printf '\nsource = %s\n' "$OVERLAY" >> "$HYPR/hyprland.conf"
else
  cat > "$HYPR/hyprland.conf" <<'EOF'
monitor=,preferred,auto,1
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = DESKTOP_SESSION,hyprland
source = $HOME/.config/hypr/99-rescue.conf
EOF
fi

if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
fi

say "DONE — Caelestia installed with swww conflict handled."
echo "Backups: $BACKUP"
echo "Log: $LOG"
echo "Reboot → choose Hyprland in SDDM. You should get wallpaper + Waybar + Kitty."