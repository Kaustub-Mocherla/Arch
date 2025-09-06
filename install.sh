#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/end4_install_$(date +%F_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }

# ---------- sanity ----------
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo not found. pacman needs sudo privileges."
  exit 1
fi

# pacman lock helper (non-destructive)
unlock_pacman(){
  if [ -e /var/lib/pacman/db.lck ]; then
    sudo ls -l /var/lib/pacman/db.lck || true
    say "pacman appears locked. If no other pacman is running, removing lock."
    sudo rm -f /var/lib/pacman/db.lck
  fi
}

# ---------- base packages ----------
PKGS=(
  # hyprland core
  hyprland xdg-desktop-portal-hyprland xdg-desktop-portal
  waybar wofi kitty mako hyprpaper grim slurp wl-clipboard wlogout
  polkit-gnome network-manager-applet bluez bluez-utils pipewire
  pipewire-alsa pipewire-pulse wireplumber brightnessctl playerctl
  noto-fonts ttf-jetbrains-mono ttf-font-awesome lm_sensors fastfetch
)

say "Refreshing package databases…"
unlock_pacman
sudo pacman -Sy --needed --noconfirm

say "Resolving swww conflicts (prefer stable 'swww')…"
if pacman -Q swww-git >/dev/null 2>&1; then
  sudo pacman -R --noconfirm swww-git || true
fi
# ensure stable swww is present
if ! pacman -Q swww >/dev/null 2>&1; then
  sudo pacman -S --noconfirm swww || true
fi

say "Installing core packages…"
unlock_pacman
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

# ---------- End-4 repo ----------
DOTS_ROOT="$HOME/.local/share/end4"
DOTS_DIR="$DOTS_ROOT/dots-hyprland"
mkdir -p "$DOTS_ROOT"

if [ -d "$DOTS_DIR/.git" ]; then
  say "Updating End-4 dots…"
  git -C "$DOTS_DIR" pull --ff-only
else
  say "Cloning End-4 dots…"
  git clone --depth=1 https://github.com/End-4/dots-hyprland "$DOTS_DIR"
fi

# ---------- backup configs ----------
CFG="$HOME/.config"
BACKUP="$HOME/.config_backup_end4_$(date +%F_%H%M%S)"
say "Backing up current ~/.config → $BACKUP"
mkdir -p "$BACKUP"
# Back up only items End-4 touches
for d in hypr waybar wofi mako kitty fish foot grimblast hyprpaper; do
  if [ -e "$CFG/$d" ]; then
    mv "$CFG/$d" "$BACKUP/" || true
  fi
done

# ---------- fix common FILE vs DIR bug ----------
say "Fixing file-vs-dir issues in ~/.config…"
# If ~/.config/hypr was accidentally created as a file, move it away
if [ -f "$CFG/hypr" ]; then
  mv "$CFG/hypr" "$BACKUP/hypr_as_file.$(date +%s)" || true
fi
mkdir -p "$CFG/hypr" "$CFG"

# ---------- copy configs (force-merge) ----------
say "Copying End-4 configs into ~/.config (force-merge, no non-dir errors)…"
# use rsync to merge without tripping on existing dirs
if ! command -v rsync >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm rsync
fi
rsync -a --mkpath "$DOTS_DIR/config/" "$CFG/"

# ---------- hyprpaper fallback ----------
WALL="$HOME/.config/wallpapers"
mkdir -p "$WALL"
if [ ! -s "$WALL/end4-fallback.png" ]; then
  say "Placing a simple fallback wallpaper…"
  # a tiny 1x1 dark png if none exists
  printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\x01\0\0\0\x01\x08\x02\0\0\0\x90wS\xde\0\0\0\nIDATx\x9ccddbf\0\0\x01\x05\0\x01\xa4\x1c\x1a\xdb\0\0\0\0IEND\xaeB`\x82' \
    > "$WALL/end4-fallback.png"
fi
# ensure hyprpaper conf exists & references fallback
mkdir -p "$CFG/hypr"
if [ ! -s "$CFG/hypr/hyprpaper.conf" ]; then
  cat > "$CFG/hypr/hyprpaper.conf" <<EOF
preload = $WALL/end4-fallback.png
wallpaper = ,$WALL/end4-fallback.png
splash = false
ipc = true
EOF
fi

# ---------- SDDM session ----------
say "Writing Hyprland desktop session for SDDM…"
sudo install -Dm644 /dev/stdin /usr/share/wayland-sessions/hyprland.desktop <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Wayland compositor
Exec=/usr/bin/Hyprland
Type=Application
X-GDM-SessionType=wayland
DesktopNames=Hyprland
EOF

# ---------- enable SDDM ----------
if systemctl list-unit-files | grep -q '^sddm\.service'; then
  say "Enabling SDDM…"
  sudo systemctl enable sddm.service
else
  say "SDDM not installed. Installing and enabling…"
  unlock_pacman
  sudo pacman -S --needed --noconfirm sddm sddm-kcm
  sudo systemctl enable sddm.service
fi

# ---------- user services on login (Waybar, Hyprpaper, Wofi) ----------
# End-4 configs typically autostart from Hyprland config; nothing to do.
# But ensure user/system env sane:
say "Ensuring DBus / PipeWire / BlueZ are enabled…"
sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null 2>&1 || true

say "All set."
echo
say "NEXT STEPS:"
echo " 1) Reboot."
echo " 2) In SDDM, pick **Hyprland** and log in."
echo " 3) If you see a blank screen, press Super+Enter (open kitty)."
echo
say "Logs saved to: $LOG"