#!/usr/bin/env bash
set -euo pipefail

# =========================
#  End-4 dots: cool install
#  - batchy, low-heat, auto-pause
# =========================

# ---------- config ----------
MAX_TEMP=85         # °C; pause if >= this
CHECK_EVERY=10      # seconds between temp checks while cooling
AUR_PKGS=(grimblast hyprpicker)   # build one-by-one
REPO_URL="https://github.com/end-4/dots-hyprland.git"
REPO_DIR="$HOME/dots-hyprland"
BACKUP_ALL="$HOME/.config_backup_end4_$(date +%F_%H%M%S)"
BACKUP_CONFLICT="$HOME/.config_end4_conflict_backup_$(date +%F_%H%M%S)"

# ---------- helpers ----------
have(){ command -v "$1" >/dev/null 2>&1; }
say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }

get_temp() {
  # requires lm_sensors; try to pull the hottest sensible CPU reading
  local t lines
  lines="$(sensors 2>/dev/null || true)"
  t=$(
    printf "%s" "$lines" |
    awk '
      /Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|Core 0:/ {
        for(i=1;i<=NF;i++) if ($i ~ /[0-9]+\.[0-9]+°C|[0-9]+°C/) {
          gsub(/°C/,"",$i); gsub(/\+|/,"",$i); print $i+0
        }
      }
      /temp1:/ { for(i=1;i<=NF;i++) if ($i ~ /[0-9]+\.[0-9]+°C|[0-9]+°C/) { gsub(/°C/,"",$i); gsub(/\+/,"",$i); print $i+0 } }
    ' 2>/dev/null |
    sort -nr | head -n1
  )
  echo "${t:-0}"
}

cool_wait() {
  # Pause if too hot
  if ! have sensors; then
    say "Installing lm_sensors for temperature checks…"
    sudo pacman -S --needed --noconfirm lm_sensors
    # (sensors works without interactive sensors-detect on most laptops)
  fi
  local t
  t="$(get_temp)"
  echo "Current CPU temp: ${t}°C  (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "Too hot. Cooling… (<= ${MAX_TEMP}°C to continue)"
    sleep "$CHECK_EVERY"
    t="$(get_temp)"
    echo "  -> ${t}°C"
  done
}

pac() { cool_wait; sudo pacman -S --needed --noconfirm "$@"; }
yay_one() { cool_wait; nice -n 19 ionice -c3 yay -S --needed --noconfirm "$1"; }

# ---------- Batch 1: pacman base (light) ----------
say "Batch 1: core packages (pacman)"
pac git base-devel jq polkit-gnome wl-clipboard grim slurp \
    playerctl brightnessctl imagemagick \
    hyprland waybar wofi kitty mako \
    pipewire pipewire-pulse wireplumber \
    xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome

say "Enable services"
cool_wait
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true
sudo systemctl enable sddm || true

# ---------- Batch 2: AUR helper + AUR pkgs (slow, cool) ----------
say "Batch 2: AUR helper (yay) at low priority"
export MAKEFLAGS="-j1"   # build with a single thread to reduce heat

if ! have yay; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cool_wait
  nice -n 19 ionice -c3 git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  ( cd "$tmp/yay" && nice -n 19 ionice -c3 makepkg -si --noconfirm )
fi

say "Build AUR packages one-by-one (cool mode)"
for p in "${AUR_PKGS[@]}"; do
  yay_one "$p"
done

# ---------- Batch 3: repo + backup (very light) ----------
say "Batch 3: backup current ~/.config and fetch end-4 repo"
mkdir -p "$BACKUP_ALL"
cp -r "$HOME/.config/." "$BACKUP_ALL/" 2>/dev/null || true
echo "Backup of your configs: $BACKUP_ALL"

if [[ -d "$REPO_DIR/.git" ]]; then
  (cd "$REPO_DIR" && git pull --ff-only)
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

# Ensure Hyprland session for SDDM
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

# ---------- Batch 4: install configs (safe merge) ----------
say "Batch 4: install configs (handle conflicts safely)"
[[ -d "$REPO_DIR/.config" ]] || { echo "Repo .config missing at $REPO_DIR"; exit 1; }

mkdir -p "$BACKUP_CONFLICT"
for item in fish foot hypr waybar wofi kitty mako; do
  if [[ -e "$HOME/.config/$item" ]]; then
    echo "Backing up conflict: ~/.config/$item -> $BACKUP_CONFLICT/"
    mv "$HOME/.config/$item" "$BACKUP_CONFLICT/" || true
  fi
done

cool_wait
cp -rT "$REPO_DIR/.config" "$HOME/.config"

# QoL: input group to silence /dev/input Waybar warnings
if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
  echo "Note: added '$USER' to group 'input' (reboot once)."
fi

# Battery name fix in Waybar if needed
BAT="$(ls /sys/class/power_supply/ 2>/dev/null | grep '^BAT' | head -n1 || true)"
if [[ -n "${BAT:-}" ]] && ls "$HOME/.config/waybar"/config* >/dev/null 2>&1; then
  for f in "$HOME/.config/waybar"/config*; do
    sed -i "s/\"BAT[0-9]\"/\"$BAT\"/g; s/\"bat[0-9]\"/\"$BAT\"/g" "$f" || true
  done
fi

say "All batches complete."

echo
echo "==================== DONE ===================="
echo "✅ end-4/dots-hyprland installed with cool/auto-pause mode"
echo "• Full backup:        $BACKUP_ALL"
echo "• Conflict backup:    $BACKUP_CONFLICT"
echo "Next:"
echo "  1) reboot"
echo "  2) choose Hyprland in SDDM"
echo "  3) log in and enjoy end-4"
echo "Tip: If you were added to 'input' group, reboot is required."
echo "=============================================="