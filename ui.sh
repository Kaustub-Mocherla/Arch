#!/usr/bin/env bash
set -euo pipefail

### ================== SAFETY / HELPERS ==================
die(){ echo "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
pkg_inst(){ pacman -Qi "$1" >/dev/null 2>&1; }
need_pkg(){ pkg_inst "$1" || sudo pacman -S --needed --noconfirm "$1"; }
append_once(){ grep -Fqx "$1" "$2" || echo "$1" >> "$2"; }

[[ -x /usr/bin/pacman ]] || die "This script is for Arch-based systems."
[[ $EUID -ne 0 ]] || die "Run as a normal user (the script will sudo when needed)."

USER_NAME="${USER}"
HOME_DIR="${HOME}"
CFG_DIR="$HOME_DIR/.config"
HYPR_DIR="$CFG_DIR/hypr"
WAYBAR_DIR="$CFG_DIR/waybar"
WALL_DIR="$CFG_DIR/wallpapers"
HYPR_CFG="$HYPR_DIR/hyprland.conf"
HYPAPER_CFG="$HYPR_DIR/hyprpaper.conf"
LOG="$HOME_DIR/caelestia_setup_$(date +%F_%H%M%S).log"

exec > >(tee -a "$LOG") 2>&1

echo "==> Starting Caelestia one-shot setup…"

### ================== PACMAN LOCK REPAIR ==================
echo "==> Checking for stale pacman locks / permissions"
if pgrep -x pacman >/dev/null || pgrep -x yay >/dev-null || pgrep -x paru >/dev/null; then
  die "Another package manager is running. Close it and re-run."
fi

# Remove stale lock if present
sudo rm -f /var/lib/pacman/db.lck || true

# Ensure /var is RW, fix perms, rebuild sync dir (covers the 'unable to lock database' we saw)
if mount | grep -E ' on /var ' | grep -q ' ro,'; then
  echo "==> Remounting /var read-write"
  sudo mount -o remount,rw /var
fi
sudo chown -R root:root /var/lib/pacman
sudo chmod -R 755 /var/lib/pacman
sudo rm -rf /var/lib/pacman/sync
sudo mkdir -p /var/lib/pacman/sync
sudo chown root:root /var/lib/pacman/sync
sudo chmod 755       /var/lib/pacman/sync

echo "==> Syncing package databases"
sudo pacman -Syy --noconfirm
echo "==> Updating system"
sudo pacman -Syu --noconfirm || true   # don't abort whole script if mirrors hiccup; we'll still install deps

### ================== CORE PACKAGES ==================
echo "==> Installing core packages"
BASE_PKGS=(
  hyprland hyprpaper waybar wofi mako kitty thunar
  pipewire pipewire-pulse wireplumber
  xdg-desktop-portal-hyprland wl-clipboard
  networkmanager network-manager-applet
  bluez bluez-utils blueman
  gvfs gvfs-mtp gvfs-smb
  qt5-wayland qt6-wayland brightnessctl playerctl
  fish git imagemagick
  sddm
)
for p in "${BASE_PKGS[@]}"; do need_pkg "$p"; done

### ================== SDDM + HYPRLAND SESSION ==================
echo "==> Enabling SDDM and writing Hyprland session file"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth || true
sudo systemctl enable sddm

### ================== AUR HELPER + SWWW-GIT ==================
install_yay(){
  if have yay; then return 0; fi
  echo "==> Installing yay (AUR helper)…"
  need_pkg base-devel
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  pushd "$tmp" >/dev/null
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  popd >/dev/null
}
SWWW_MODE="hyprpaper"
if ! have swww || ! swww --help 2>/dev/null | grep -q '\binit\b'; then
  echo "==> Installing swww-git (AUR) for proper 'init' support"
  # remove repo swww if present (the one without 'init')
  sudo pacman -R --noconfirm swww >/dev/null 2>&1 || true
  install_yay || true
  if have yay; then yay -S --needed --noconfirm swww-git || true; fi
fi
if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
  SWWW_MODE="swww"
fi
echo "==> Wallpaper backend: $SWWW_MODE"

### ================== CAELESTIA REPO + INSTALLER ==================
echo "==> Cloning Caelestia shell and running install.fish (as in video)"
mkdir -p "$HOME_DIR/.local/share"
if [[ ! -d "$HOME_DIR/.local/share/caelestia" ]]; then
  git clone https://github.com/caelestia-dots/shell "$HOME_DIR/.local/share/caelestia"
else
  echo "Repo already exists, pulling latest…"
  git -C "$HOME_DIR/.local/share/caelestia" pull --ff-only || true
fi
# Run the official installer
if [[ -f "$HOME_DIR/.local/share/caelestia/install.fish" ]]; then
  need_pkg fish
  fish "$HOME_DIR/.local/share/caelestia/install.fish" || true
fi

### ================== WALLPAPER + CONFIG FIXUPS ==================
echo "==> Ensuring wallpaper image"
mkdir -p "$WALL_DIR"
if ! ls "$WALL_DIR"/* >/dev/null 2>&1; then
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$WALL_DIR/caelestia-fallback.png"
fi
WP_IMG="$(ls -1 "$WALL_DIR"/* | head -n1)"
echo "Using wallpaper: $WP_IMG"

echo "==> Ensuring Hypr config exists"
mkdir -p "$HYPR_DIR"
if [[ ! -f "$HYPR_CFG" ]]; then
  cat > "$HYPR_CFG" <<'EOF'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
EOF
fi
cp -a "$HYPR_CFG" "$HYPR_CFG.backup.$(date +%Y%m%d-%H%M%S)"

# remove possible duplicates from earlier attempts
sed -i \
  -e '/^\s*exec-once\s*=\s*swww\b/d' \
  -e '/^\s*exec-once\s*=\s*hyprpaper\b/d' \
  -e '/^\s*exec-once\s*=\s*waybar\b/d' \
  -e '/^\s*exec-once\s*=\s*mako\b/d' \
  -e '/^\s*bind\s*=\s*SUPER,RETURN,exec,kitty\b/d' \
  -e '/^\s*bind\s*=\s*SUPER,SPACE,exec,wofi\b/d' \
  "$HYPR_CFG"

# write clean autostarts
{
  echo
  echo "### === AUTOSTART (written by caelestia_setup_full.sh) ==="
  if [[ "$SWWW_MODE" == "swww" ]]; then
    echo "exec-once = swww init"
    echo "exec-once = swww img $WP_IMG"
  else
    cat > "$HYPAPER_CFG" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash = false
EOF
    echo "exec-once = hyprpaper &"
  fi
  echo "exec-once = waybar"
  echo "exec-once = mako"
  echo
  echo "### === KEYBINDS ==="
  echo "bind = SUPER,RETURN,exec,kitty"
  echo "bind = SUPER,SPACE,exec,wofi --show drun"
} >> "$HYPR_CFG"

### ================== WAYBAR FIXES (input group + battery) ==================
echo "==> Adding $USER_NAME to 'input' group (fix Waybar /dev/input warnings)"
if ! id -nG "$USER_NAME" | grep -qw input; then
  sudo usermod -aG input "$USER_NAME"
  INPUT_NOTE="(You must log out/in or reboot for new group to apply.)"
else
  INPUT_NOTE="(already in input group)"
fi

echo "==> Fixing Waybar battery device if present"
mkdir -p "$WAYBAR_DIR"
BAT_NAME=""
if ls /sys/class/power_supply/ 2>/dev/null | grep -q '^BAT'; then
  BAT_NAME="$(ls /sys/class/power_supply/ | grep '^BAT' | head -n1)"
  # patch common waybar configs (json/jsonc)
  if ls "$WAYBAR_DIR"/config* >/dev/null 2>&1; then
    for f in "$WAYBAR_DIR"/config*; do
      sed -i "s/\"bat[0-9]\"/\"$BAT_NAME\"/g; s/\"BAT[0-9]\"/\"$BAT_NAME\"/g" "$f" || true
    done
  fi
fi

### ================== APPLY NOW IF INSIDE HYPRLAND ==================
INSIDE_HYPR=0
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && have hyprctl; then
  INSIDE_HYPR=1
  echo "==> Applying immediately (inside Hyprland)"
  pkill -x waybar      >/dev/null 2>&1 || true
  pkill -x mako        >/dev/null 2>&1 || true
  pkill -x hyprpaper   >/dev/null 2>&1 || true
  pkill -x swww-daemon >/dev/null 2>&1 || true

  if [[ "$SWWW_MODE" == "swww" ]]; then
    swww init || true
    swww img "$WP_IMG" || true
  else
    hyprpaper & disown
  fi
  waybar & disown
  mako & disown
  hyprctl reload -r || true
fi

### ================== SUMMARY ==================
echo
echo "==================== DONE ===================="
echo "Log: $LOG"
echo "Wallpaper backend: $SWWW_MODE"
echo "Wallpaper image:   $WP_IMG"
echo "Hypr config:       $HYPR_CFG (backup created)"
echo "Waybar battery:    ${BAT_NAME:-<none detected>}"
echo "Input group fix:   $INPUT_NOTE"
if [[ $INSIDE_HYPR -eq 1 ]]; then
  echo "Applied now. Try: Super+Enter (Kitty), Super+Space (Wofi)."
else
  echo "Now reboot, choose **Hyprland** in SDDM, and log in."
fi
echo "================================================"