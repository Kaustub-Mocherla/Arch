#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/one_fix_$(date +%F_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

need() { command -v "$1" >/dev/null 2>&1; }
pkg()  { pacman -Qi "$1" >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm "$1"; }

if [[ $EUID -eq 0 ]]; then echo "Run as a normal user (uses sudo)."; exit 1; fi
need pacman || { echo "This script is for Arch/Arch-based systems."; exit 1; }

echo "==> Step 1: ensure no package managers are running"
if pgrep -x pacman >/dev/null || pgrep -x yay >/dev/null || pgrep -x paru >/dev/null; then
  echo "Found a running package manager. Close it and re-run."; exit 1
fi

echo "==> Step 2: unlock/fix pacman DB"
# Remount /var RW if RO
if mount | grep -E ' on /var ' | grep -q ' ro,'; then
  echo "Remounting /var read-write"
  sudo mount -o remount,rw /var
fi
# Remove stale lock if present
sudo rm -f /var/lib/pacman/db.lck || true
# Fix permissions
sudo chown -R root:root /var/lib/pacman
sudo chmod -R 755       /var/lib/pacman
# Recreate sync dir cleanly
sudo rm -rf /var/lib/pacman/sync
sudo mkdir -p /var/lib/pacman/sync
sudo chown root:root /var/lib/pacman/sync
sudo chmod 755       /var/lib/pacman/sync

echo "==> Step 3: refresh DBs (force) and full update"
sudo pacman -Syy --noconfirm
sudo pacman -Syu  --noconfirm

echo "==> Step 4: core desktop deps (Hyprland/Caelestia)"
CORE_PKGS=(
  hyprland hyprpaper waybar wofi mako kitty thunar
  xdg-desktop-portal-hyprland wl-clipboard
  pipewire pipewire-pulse wireplumber
  networkmanager network-manager-applet
  bluez bluez-utils blueman
  gvfs gvfs-mtp gvfs-smb
  qt5-wayland qt6-wayland brightnessctl playerctl
  imagemagick git fish
)
for p in "${CORE_PKGS[@]}"; do pkg "$p"; done

echo "==> Step 5: services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth || true
pkg sddm
sudo systemctl enable sddm

echo "==> Step 6: ensure Hyprland session file (SDDM)"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

echo "==> Step 7: wallpaper tool (prefer swww with 'init' support)"
aur_install() {
  local pkg="$1"
  if need yay; then yay -S --needed --noconfirm "$pkg"
  elif need paru; then paru -S --needed --noconfirm "$pkg"
  else return 1; fi
}
SWWW_OK=0
if need swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
  SWWW_OK=1
else
  sudo pacman -R --noconfirm swww || true
  aur_install swww-git || true
  if need swww && swww --help 2>/dev/null | grep -q '\binit\b'; then SWWW_OK=1; fi
fi

echo "==> Step 8: ensure configs & autostarts"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/wallpapers"
CFG="$HOME/.config/hypr/hyprland.conf"
[[ -f "$CFG" ]] || cat > "$CFG" <<'MINI'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
# Launcher
bind = SUPER,SPACE,exec,wofi --show drun
MINI

# Basic wallpaper (fallback) if none found
if ! ls "$HOME/.config/wallpapers/"* >/dev/null 2>&1; then
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$HOME/.config/wallpapers/caelestia-fallback.png"
fi
WP_IMG="$(ls -1 "$HOME/.config/wallpapers/"* | head -n1)"

# If NVIDIA, add safe env
if lspci -nnk | grep -qi nvidia; then
  grep -q "WLR_NO_HARDWARE_CURSORS" "$CFG" 2>/dev/null || echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$CFG"
fi

# Hyprpaper cfg if swww not available
if [[ $SWWW_OK -eq 0 ]]; then
  cat > "$HOME/.config/hypr/hyprpaper.conf" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash = false
EOF
fi

ensure_line() { grep -Fqx "$1" "$CFG" || echo "$1" >> "$CFG"; }

# Remove any previously disabled exec-once markers
sed -i 's/^## disabled-by-script: exec-once =/exec-once =/g' "$CFG" || true

if [[ $SWWW_OK -eq 1 ]]; then
  ensure_line "exec-once = swww init"
  ensure_line "exec-once = swww img $WP_IMG"
else
  ensure_line "exec-once = hyprpaper &"
fi
ensure_line "exec-once = waybar &"
ensure_line "exec-once = mako &"

echo "==> Step 9: try applying now if inside Hyprland"
if need hyprctl && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  if [[ $SWWW_OK -eq 1 ]]; then
    (swww query >/dev/null 2>&1) || swww init || true
    swww img "$WP_IMG" || true
  else
    pkill -x hyprpaper >/dev/null 2>&1 || true
    hyprpaper & disown || true
  fi
  pgrep -x waybar >/dev/null || (waybar & disown)
  pgrep -x mako   >/dev/null || (mako   & disown)
  hyprctl reload -r || true
else
  echo "Not in a Hyprland session; changes will take effect next login."
fi

echo
echo "================= DONE ================="
echo "Log: $LOG"
echo "If pacman still says 'unable to lock database', run:"
echo "  ls -ld /var/lib/pacman /var/lib/pacman/sync"
echo "and share the output."
echo "Reboot, pick Hyprland in SDDM, log in."
echo "========================================"