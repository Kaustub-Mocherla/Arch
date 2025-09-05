#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/caelestia_repair_$(date +%F_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

need_cmd(){ command -v "$1" >/dev/null 2>&1; }
need_pkg(){ pacman -Qi "$1" >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm "$1"; }
aur_install(){
  local pkg="$1"
  if need_cmd yay;  then yay  -S --needed --noconfirm "$pkg"
  elif need_cmd paru; then paru -S --needed --noconfirm "$pkg"
  else
    echo "AUR helper not found; skipping $pkg. Install yay/paru to get it automatically."
    return 1
  fi
}

if [[ $EUID -eq 0 ]]; then echo "Run as a normal user (script will sudo)."; exit 1; fi
need_cmd pacman || { echo "This script requires Arch/Artix (pacman)."; exit 1; }

echo "==> Syncing repos"
sudo pacman -Syu --noconfirm

echo "==> Installing core deps"
CORE_PKGS=(
  hyprland hyprpaper waybar wofi mako kitty thunar
  xdg-desktop-portal-hyprland wl-clipboard
  pipewire pipewire-pulse wireplumber
  networkmanager network-manager-applet
  bluez bluez-utils blueman
  gvfs gvfs-mtp gvfs-smb
  qt5-wayland qt6-wayland brightnessctl playerctl
  imagemagick # for fallback wallpaper
)
for p in "${CORE_PKGS[@]}"; do need_pkg "$p"; done

echo "==> Ensure SDDM + session"
need_pkg sddm
sudo systemctl enable sddm >/dev/null 2>&1 || true
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

echo "==> Enable NetworkManager/Bluetooth"
sudo systemctl enable --now NetworkManager >/dev/null 2>&1 || true
sudo systemctl enable --now bluetooth       >/dev/null 2>&1 || true

GPU_INFO="$(lspci -nnk | grep -E 'VGA|3D|Display' || true)"
echo "==> GPU: $GPU_INFO"
mkdir -p "$HOME/.config/hypr"
CFG="$HOME/.config/hypr/hyprland.conf"
[[ -f "$CFG" ]] || cat > "$CFG" <<'MINI'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
MINI

# NVIDIA cursor fix if applicable
if grep -qi nvidia <<<"$GPU_INFO"; then
  grep -q "WLR_NO_HARDWARE_CURSORS" "$CFG" 2>/dev/null || \
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$CFG"
fi

echo "==> Ensure wallpaper directory and image"
WPDIR="$HOME/.config/wallpapers"
mkdir -p "$WPDIR"
# Make a fallback wallpaper if none exist
if ! ls "$WPDIR"/* >/dev/null 2>&1; then
  need_pkg imagemagick
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$WPDIR/caelestia-fallback.png"
fi
WP_IMG="$(ls -1 "$WPDIR"/* | head -n1)"

echo "==> swww check"
SWWW_OK=0
if need_cmd swww; then
  if swww --help 2>/dev/null | grep -q '\binit\b'; then
    SWWW_OK=1
  else
    echo "Installed swww lacks 'init'; attempting to replace with swww-git (AUR)."
    sudo pacman -R --noconfirm swww || true
  fi
fi
if [[ $SWWW_OK -eq 0 ]]; then
  aur_install swww-git || echo "Skipping swww-git (no AUR helper). Will use hyprpaper fallback."
  if need_cmd swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
    SWWW_OK=1
  fi
fi

# Ensure hyprpaper config if needed
HYP_PAPER_CFG="$HOME/.config/hypr/hyprpaper.conf"
if [[ $SWWW_OK -eq 0 ]]; then
  cat > "$HYP_PAPER_CFG" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash = false
EOF
fi

echo "==> Ensure exec-once autostarts"
ensure_line(){
  local line="$1"
  grep -Fqx "$line" "$CFG" || echo "$line" >> "$CFG"
}
# Kill any previously disabled exec-once comment marker we might have used
sed -i 's/^## disabled-by-script: exec-once =/exec-once =/g' "$CFG" || true

if [[ $SWWW_OK -eq 1 ]]; then
  ensure_line "exec-once = swww init"
  ensure_line "exec-once = swww img $WP_IMG"
else
  ensure_line "exec-once = hyprpaper &"
fi
ensure_line "exec-once = waybar &"
ensure_line "exec-once = mako &"

# launcher keybind (optional if missing)
grep -q "bind = SUPER,SPACE" "$CFG" || cat >> "$CFG" <<'BIND'
# Launcher
bind = SUPER,SPACE,exec,wofi --show drun
BIND

echo "==> Permissions sanity"
sudo chown -R "$USER:$USER" "$HOME"
chmod 700 "$HOME"

echo "==> Try to (re)start components now (if inside Hyprland)"
if need_cmd hyprctl && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  # Start wallpaper
  if [[ $SWWW_OK -eq 1 ]]; then
    (swww query >/dev/null 2>&1) || swww init || true
    swww img "$WP_IMG" || true
  else
    pkill -x hyprpaper >/dev/null 2>&1 || true
    hyprpaper & disown || true
  fi
  # Start bar/notifications if not running
  pgrep -x waybar >/dev/null || (waybar & disown)
  pgrep -x mako   >/dev/null || (mako   & disown)
  hyprctl reload -r || true
else
  echo "Not in a running Hyprland session; will take effect next login."
fi

echo
echo "==================== SUMMARY ===================="
echo "Log file: $LOG"
echo "Wallpaper image: $WP_IMG"
echo "Used wallpaper tool: $([[ $SWWW_OK -eq 1 ]] && echo swww || echo hyprpaper)"
echo "Hypr config updated at: $CFG"
echo "Services: SDDM $(systemctl is-enabled sddm 2>/dev/null), NM $(systemctl is-enabled NetworkManager 2>/dev/null), BT $(systemctl is-enabled bluetooth 2>/dev/null || true)"
echo "If bar/launcher still missing, run inside Hyprland:"
echo "  waybar &    ;  mako &    ;  wofi --show drun &"
echo "================================================="