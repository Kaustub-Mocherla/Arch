#!/usr/bin/env bash
set -euo pipefail

# ===== One-shot Caelestia installer (heat-safe + conflicts fixed) =====
# You can override temps per-run:
#   MAX_TEMP=80 CHECK_EVERY=15 bash install_caelestia_cool.sh

MAX_TEMP="${MAX_TEMP:-85}"           # °C threshold to pause
CHECK_EVERY="${CHECK_EVERY:-10}"     # seconds between temp checks

CAEL_URL="https://github.com/caelestia-dots/shell.git"
CAEL_DIR="$HOME/.local/share/caelestia"

CFG="$HOME/.config"
HYPR="$CFG/hypr"
WB="$CFG/waybar"
WOFI="$CFG/wofi"
KITTY="$CFG/kitty"
WPDIR="$CFG/wallpapers"

LOG="$HOME/caelestia_full_install_$(date +%F_%H%M%S).log"

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

cpu_temp() {
  local t
  t="$(sensors 2>/dev/null | awk '/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{
    for(i=1;i<=NF;i++) if($i~/[0-9]+(\.[0-9]+)?°C/){gsub(/[+°C]/,"",$i); print $i+0}
  }' | sort -nr | head -n1)"
  echo "${t:-0}"
}
cool_wait() {
  if ! have sensors; then sudo pacman -S --needed --noconfirm lm_sensors; fi
  local t; t="$(cpu_temp)"
  echo "CPU temp: ${t}°C (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "… cooling (waiting ${CHECK_EVERY}s)"; sleep "$CHECK_EVERY"
    t="$(cpu_temp)"; echo "  -> ${t}°C"
  done
}
pac(){ cool_wait; sudo pacman -S --needed --noconfirm "$@"; }

# --- log everything ---
exec > >(tee -a "$LOG") 2>&1

# --- stop possible daemons to avoid conflicts ---
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
pkill -x swww 2>/dev/null || true
pkill -x mako 2>/dev/null || true

# --- prerequisites ---
say "Installing prerequisites (lm_sensors, base-devel, git, fish)…"
pac lm_sensors base-devel git fish

# --- make sure yay exists ---
if ! have yay; then
  say "Installing yay (AUR helper)…"
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  ( cd "$tmpdir/yay"; cool_wait; nice -n 19 ionice -c3 makepkg -si --noconfirm )
  rm -rf "$tmpdir"
fi

# --- remove stable swww (conflicts with swww-git) ---
if pacman -Qi swww &>/dev/null; then
  say "Removing stable swww (conflicts with swww-git)…"
  sudo pacman -Rns --noconfirm swww || true
fi

# --- prefer swww-git + Caelestia CLI ---
say "Installing swww-git + caelestia-cli-git (AUR)…"
cool_wait
nice -n 19 ionice -c3 yay -S --needed --noconfirm swww-git caelestia-cli-git

# --- core runtime from repos ---
say "Installing core Wayland/Hyprland runtime…"
pac hyprland sddm waybar wofi kitty mako hyprpaper \
    wl-clipboard grim slurp jq \
    pipewire pipewire-pulse wireplumber polkit-gnome \
    xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome imagemagick

# --- SDDM session fix + enable ---
say "Ensuring SDDM starts Hyprland via dbus-run-session…"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF
sudo systemctl enable --now sddm || true
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true

# --- clone/update Caelestia repo ---
say "Cloning/updating Caelestia repo…"
mkdir -p "$(dirname "$CAEL_DIR")"
if [[ -d "$CAEL_DIR/.git" ]]; then
  git -C "$CAEL_DIR" pull --ff-only
else
  git clone "$CAEL_URL" "$CAEL_DIR"
fi

# --- write heat-safe fish runner that will source install.fish ---
RUNF="$CAEL_DIR/.cool_run_install.fish"
say "Preparing heat-safe runner…"
cat >"$RUNF" <<'FISH'
# Heat-safe wrappers inside fish; relies on env MAX_TEMP/CHECK_EVERY
function __cool_get_temp
  bash -lc 'sensors 2>/dev/null | awk "/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{for(i=1;i<=NF;i++) if(\$i~/[0-9]+(\\.[0-9]+)?°C/){gsub(/[+°C]/,\"\",$i); print \$i+0}}\" | sort -nr | head -n1'
end
function cool_wait
  if not type -q sensors
    sudo pacman -S --needed --noconfirm lm_sensors >/dev/null 2>&1
  end
  set -l t (__cool_get_temp)
  if test -z "$t"; set t 0; end
  echo "CPU temp: $t°C (limit $MAX_TEMP°C)"
  while test (math "floor($t)") -ge $MAX_TEMP
    echo "… cooling (sleep $CHECK_EVERY s)"
    sleep $CHECK_EVERY
    set t (__cool_get_temp)
  end
end
set -x MAKEFLAGS -j1
set -x CFLAGS "-O2"
set -x CXXFLAGS "-O2"
functions -q yay;    and functions -c yay    __orig_yay
functions -q paru;   and functions -c paru   __orig_paru
functions -q pacman; and functions -c pacman __orig_pacman
functions -q makepkg;and functions -c makepkg __orig_makepkg
functions -q git;    and functions -c git    __orig_git
functions -q cmake;  and functions -c cmake  __orig_cmake
functions -q ninja;  and functions -c ninja  __orig_ninja
function yay;    cool_wait; command nice -n 19 ionice -c3 __orig_yay $argv;    end
function paru;   cool_wait; command nice -n 19 ionice -c3 __orig_paru $argv;   end
function pacman; cool_wait; command nice -n 19 ionice -c3 __orig_pacman $argv; end
function makepkg;cool_wait; command nice -n 19 ionice -c3 __orig_makepkg $argv;end
function git;    cool_wait; command nice -n 19 ionice -c3 __orig_git $argv;    end
function cmake;  cool_wait; command nice -n 19 ionice -c3 __orig_cmake $argv;  end
function ninja;  cool_wait; command nice -n 19 ionice -c3 __orig_ninja $argv;  end
# run upstream installer exactly like the video
source ~/.local/share/caelestia/install.fish
FISH

# --- create minimal rescue overlay (never blank screen) ---
say "Adding rescue overlay (wallpaper + waybar + kitty)…"
mkdir -p "$HYPR" "$WB" "$WOFI" "$KITTY" "$WPDIR"
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
  "network":{"format-wifi":"{essid} {signalStrength}%"},
  "battery":{"bat":"$BAT","format":"{capacity}%"}
}
EOF
cat > "$WB/style.css" <<'EOF'
* { font-family: JetBrainsMono, Noto Sans, FontAwesome; font-size: 12px; }
window#waybar { background: rgba(22,22,28,0.85); color: #ddd; }
#battery.critical { color: #e06c75; }
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
waybar &  # bar
mako &    # notifications (if present)
kitty &   # terminal always available
EOF
chmod +x "$HYPR/autostart.sh"

cat > "$HYPR/99-rescue.conf" <<'EOF'
env = WLR_NO_HARDWARE_CURSORS,1
exec-once = $HOME/.config/hypr/autostart.sh
bind = SUPER, RETURN, exec, kitty
bind = SUPER, C, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, R, exec, hyprctl reload
EOF

if [[ -f "$HYPR/hyprland.conf" ]]; then
  grep -q '99-rescue.conf' "$HYPR/hyprland.conf" || printf '\nsource = %s\n' "$HYPR/99-rescue.conf" >> "$HYPR/hyprland.conf"
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

# input group (fix /dev/input EACCES warnings)
if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
fi

# --- run installer via fish wrapper ---
export MAX_TEMP CHECK_EVERY
say "Running Caelestia install.fish through heat-safe wrapper…"
fish "$RUNF" || true   # allow upstream non-fatal warnings

say "All done. Reboot and choose **Hyprland** in SDDM."
echo "Log: $LOG"
echo "You should always get wallpaper + Waybar + Kitty."