#!/usr/bin/env bash
set -euo pipefail

# ===== Caelestia clean install (after end-4), with safe fallback + cool mode =====

# ---- heat limits ----
MAX_TEMP=85         # °C: pause above this
CHECK_EVERY=10      # seconds between temp checks

# ---- paths ----
END4_REPO="$HOME/dots-hyprland"
CAEL_REPO_URL="https://github.com/caelestia-dots/shell.git"
CAEL_REPO="$HOME/.local/share/caelestia"
CFG="$HOME/.config"
HYPR="$CFG/hypr"
WB="$CFG/waybar"
WOFI="$CFG/wofi"
KITTY="$CFG/kitty"
FISHCFG="$CFG/fish"
FOOTCFG="$CFG/foot"
WPDIR="$CFG/wallpapers"
LOG="$HOME/caelestia_clean_install_$(date +%F_%H%M%S).log"

# ---- helpers ----
say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
cpu_temp(){
  local lines t
  lines="$(sensors 2>/dev/null || true)"
  t=$(
    printf "%s" "$lines" |
    awk '/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{
      for(i=1;i<=NF;i++) if ($i ~ /[0-9]+(\.[0-9]+)?°C/){ gsub(/°C|\+/,"",$i); print $i+0 }
    }' | sort -nr | head -n1
  )
  echo "${t:-0}"
}
cool_wait(){
  if ! have sensors; then
    sudo pacman -S --needed --noconfirm lm_sensors
  fi
  local t; t="$(cpu_temp)"
  echo "CPU temp: ${t}°C (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "…cooling (<= ${MAX_TEMP}°C to continue)"
    sleep "$CHECK_EVERY"
    t="$(cpu_temp)"; echo "  -> ${t}°C"
  done
}
pac(){ cool_wait; sudo pacman -S --needed --noconfirm "$@"; }

# ---- log everything ----
exec > >(tee -a "$LOG") 2>&1

say "Stopping running bar/wallpaper to avoid conflicts…"
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
pkill -x swww 2>/dev/null || true
pkill -x mako 2>/dev/null || true

# ------------------------------------------------------------------------------
# 1) CLEAN END-4 LEFTOVERS (configs -> backup, repo removed)
# ------------------------------------------------------------------------------
BACKUP="$HOME/.config_end4_cleanup_$(date +%F_%H%M%S)"
say "Backing up end-4 related configs to: $BACKUP"
mkdir -p "$BACKUP"

for d in hypr waybar wofi kitty fish foot; do
  if [[ -e "$CFG/$d" ]]; then
    mv "$CFG/$d" "$BACKUP/" || true
    echo "  moved ~/.config/$d -> $BACKUP/"
  fi
done

if [[ -d "$END4_REPO/.git" ]]; then
  say "Removing end-4 repo: $END4_REPO"
  rm -rf "$END4_REPO"
fi

mkdir -p "$HYPR" "$WB" "$WOFI" "$KITTY" "$WPDIR"

# ------------------------------------------------------------------------------
# 2) RUNTIME PACKAGES (pacman only; stable)
# ------------------------------------------------------------------------------
say "Installing core Wayland/Hyprland runtime + tools…"
pac hyprland sddm fish git \
    waybar wofi kitty mako \
    swww hyprpaper wl-clipboard grim slurp jq \
    pipewire pipewire-pulse wireplumber polkit-gnome \
    xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome \
    imagemagick lm_sensors

say "Enabling display/network services…"
sudo systemctl enable --now sddm || true
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true

# ------------------------------------------------------------------------------
# 3) SDDM SESSION FIX (dbus-run-session Hyprland)
# ------------------------------------------------------------------------------
say "Ensuring SDDM uses dbus-run-session for Hyprland…"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

# ------------------------------------------------------------------------------
# 4) CLONE & RUN CAELESTIA install.fish
# ------------------------------------------------------------------------------
say "Cloning/updating Caelestia-shell repo…"
mkdir -p "$(dirname "$CAEL_REPO")"
if [[ -d "$CAEL_REPO/.git" ]]; then
  git -C "$CAEL_REPO" pull --ff-only
else
  git clone "$CAEL_REPO_URL" "$CAEL_REPO"
fi

say "Running Caelestia install.fish (as in the video)…"
pac fish
cool_wait
fish -c "$CAEL_REPO/install.fish"

# ------------------------------------------------------------------------------
# 5) BULLETPROOF FALLBACK (never blank screen)
#    - minimal waybar + wallpaper + kitty autostart
#    - added as overlay include so it coexists with Caelestia
# ------------------------------------------------------------------------------
say "Setting up rescue overlay so session always comes up…"

# one wallpaper for sure
if ! ls "$WPDIR"/* >/dev/null 2>&1; then
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$WPDIR/caelestia-fallback.png"
fi
WP="$(ls -1 "$WPDIR"/* | head -n1)"

# battery for waybar (avoid crashes)
BAT="$(ls /sys/class/power_supply/ 2>/dev/null | grep '^BAT' | head -n1 || true)"
[[ -z "${BAT:-}" ]] && BAT="BAT0"

# safe waybar (tiny)
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

# wofi/kitty small defaults (harmless if Caelestia overwrites)
cat > "$WOFI/style.css" <<'EOF'
window { background-color: rgba(22,22,28,0.95); }
#input { padding: 6px; }
EOF
cat > "$KITTY/kitty.conf" <<'EOF'
font_family JetBrains Mono
font_size   11
enable_audio_bell no
EOF

# autostart helper
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

waybar &   # safe bar
mako &     # notifications
kitty &    # ensure a terminal
EOF
chmod +x "$HYPR/autostart.sh"

# overlay that Caelestia will source or we’ll force-source
OVERLAY="$HYPR/99-rescue.conf"
cat > "$OVERLAY" <<'EOF'
# === Caelestia Rescue Overlay (kept tiny; safe to keep) ===
env = WLR_NO_HARDWARE_CURSORS,1
exec-once = $HOME/.config/hypr/autostart.sh
bind = SUPER, RETURN, exec, kitty
bind = SUPER, C, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, R, exec, hyprctl reload
EOF

# make sure hyprland.conf includes overlay (whether Caelestia created one or not)
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

# /dev/input warnings fix
if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
fi

# ------------------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------------------
say "DONE — Caelestia installed & end-4 cleaned."
echo "Backups placed at: $BACKUP"
echo "Log: $LOG"
echo
echo "Now: reboot → choose **Hyprland** in SDDM."
echo "You should ALWAYS get wallpaper + Waybar + Kitty (Wofi = SUPER+C)."
echo
echo "If something fails:  tail -n 200 ~/.local/share/sddm/wayland-session.log"