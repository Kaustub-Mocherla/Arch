#!/usr/bin/env bash
# install_caelestia_cool.sh
# One-shot, heat-safe installer/repairer for Caelestia-Shell on Arch
# - runs in batches with pauses
# - auto-handles swww/swww-git conflicts
# - (re)installs yay if missing
# - backs up your ~/.config
# - runs Caelestia install.fish with a cooldown wrapper
# - finishes CLI + Hyprland/session bits

set -euo pipefail

# -------- settings you can tweak --------
MAX_TEMP="${MAX_TEMP:-82}"        # °C ceiling before pausing builds
CHECK_EVERY="${CHECK_EVERY:-15}"  # seconds between temp checks while building
PAUSE_SECS="${PAUSE_SECS:-3}"     # short automatic pause between batches
# ---------------------------------------

say() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\n\033[1;31m[err]\033[0m %s\n" "$*"; exit 1; }

# Make sure we are not root (we'll use sudo)
if [[ $EUID -eq 0 ]]; then
  die "Run as your normal user (not root)."
fi

# quick helper: read max temp from /sys (fallback to 0 if sensors missing)
read_max_temp() {
  local t max=0
  for z in /sys/class/thermal/thermal_zone*/temp; do
    [[ -r "$z" ]] || continue
    t=$(<"$z")
    (( t > max )) && max="$t"
  done
  # convert millidegC -> °C
  echo $(( max/1000 ))
}

cooldown_gate() {
  say "Thermal gate: waiting if CPU temp >= ${MAX_TEMP}°C (checks every ${CHECK_EVERY}s)…"
  while :; do
    local cur; cur="$(read_max_temp)"
    printf "  current temp: %s°C\r" "$cur"
    if (( cur < MAX_TEMP )); then
      echo
      break
    fi
    sleep "$CHECK_EVERY"
  done
}

press_enter() {
  read -r -p $'\n[PAUSE] Press ENTER to continue… ' _ || true
}

short_pause() { sleep "$PAUSE_SECS"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

LOG_DIR="$HOME"
RUN_LOG="$LOG_DIR/caelestia_cool_install_$(date +%F_%H%M%S).log"
exec > >(tee -a "$RUN_LOG") 2>&1

say "Logs: $RUN_LOG"
say "Run this from a TTY (Ctrl+Alt+F3)."

# ---------------- Batch 1: base tools ----------------
say "Installing minimal prerequisites."
cooldown_gate
sudo pacman -Syu --needed --noconfirm \
  git fish lm_sensors python-pip python \
  base-devel

short_pause; press_enter

# ---------------- Batch 2: fix conflicts & yay ----------------
say "Removing stable swww if present (to avoid conflict with swww-git)."
sudo pacman -R --noconfirm swww || true

say "Ensuring yay (AUR helper) is available."
if ! need_cmd yay; then
  cooldown_gate
  rm -rf "$HOME/yay"
  git clone https://aur.archlinux.org/yay.git "$HOME/yay"
  ( cd "$HOME/yay" && makepkg -si --noconfirm )
else
  say "yay already installed."
fi

short_pause; press_enter

# ---------------- Batch 3: core Hypr + companions ----------------
say "Installing Hyprland + companions (repo packages)."
cooldown_gate
sudo pacman -S --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland \
  waybar wofi kitty mako hyprpaper wl-clipboard grimblast \
  qt6ct qt5ct pipewire wireplumber polkit-gnome \
  noto-fonts ttf-jetbrains-mono ttf-font-awesome lm_sensors

short_pause; press_enter

say "Installing swww-git (AUR) for wallpaper transitions."
cooldown_gate
yay -S --needed --noconfirm swww-git

short_pause; press_enter

# ---------------- Batch 4: SDDM + session ----------------
say "Installing & enabling SDDM (display manager)."
cooldown_gate
sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm.service

# Ensure Hyprland session desktop file exists (normally provided)
if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
  say "Creating Hyprland desktop file for SDDM."
  tmpf="$(mktemp)"
  cat >"$tmpf" <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=/usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
EOF
  sudo install -m 644 "$tmpf" /usr/share/wayland-sessions/hyprland.desktop
  rm -f "$tmpf"
fi

short_pause; press_enter

# ---------------- Batch 5: clone Caelestia & backup configs ----------------
CE_DIR="$HOME/.local/share/caelestia"
say "Cloning Caelestia-Shell repo."
cooldown_gate
rm -rf "$CE_DIR"
git clone https://github.com/caelestia-dots/shell "$CE_DIR"

BACKUP_DIR="$HOME/.config_backup_caelestia_$(date +%F_%H%M%S)"
say "Backing up your ~/.config to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
# light, safe backup (don’t fail if some are missing)
rsync -a --delete --mkpath "$HOME/.config/" "$BACKUP_DIR/" || true

short_pause; press_enter

# ---------------- Batch 6: run Caelestia installer (heat-safe) ----------------
say "Preparing heat-safe runner for Caelestia install."
RUNNER="$CE_DIR/_cool_run_install.fish"
cat >"$RUNNER" <<'FISH'
function read_max_temp --description "Return max temp (°C) across thermal zones"
  set -l max 0
  for z in /sys/class/thermal/thermal_zone*/temp
    if test -r $z
      set t (cat $z)
      set t (math "$t / 1000")
      if test $t -gt $max
        set max $t
      end
    end
  end
  echo $max
end

set -l MAX_TEMP (string replace -r '.*=' '' (string match -r 'MAX_TEMP=.*' (env)))[1]
set -q MAX_TEMP; or set MAX_TEMP 82
set -l CHECK_EVERY (string replace -r '.*=' '' (string match -r 'CHECK_EVERY=.*' (env)))[1]
set -q CHECK_EVERY; or set CHECK_EVERY 15

function cool_gate
  echo (set_color cyan)"[cooldown] waiting if temp >= $MAX_TEMP°C …"(set_color normal)
  while true
    set cur (read_max_temp)
    printf "  temp: %s°C\r" $cur
    if test "$cur" -lt "$MAX_TEMP"
      echo
      break
    end
    sleep $CHECK_EVERY
  end
end

cool_gate

# run the official installer (interactive; you choose backup option)
source ~/.local/share/caelestia/install.fish
FISH

say "Starting Caelestia install (you will see its menu)."
say "TIP: choose 'Make one for me please' when asked to backup config."
cooldown_gate
# Run under fish so its ANSI prompts render correctly.
fish "$RUNNER" || warn "Installer returned a non-zero status (continuing)."

short_pause; press_enter

# ---------------- Batch 7: ensure Caelestia CLI is available ----------------
say "Ensuring 'caelestia' CLI (Python) is installed."
cooldown_gate
python3 -m pip install --user --upgrade caelestia || warn "pip install caelestia failed (will proceed)."

# Try to finalize theme & shell configs (these do not require Hyprland running)
if command -v caelestia >/dev/null 2>&1; then
  say "Applying default Caelestia scheme and shell configs."
  caelestia scheme set -n shadotheme || warn "scheme apply skipped."
  caelestia shell -d || warn "shell apply skipped."
else
  warn "'caelestia' command not found after install; skipping scheme/shell apply."
fi

short_pause; press_enter

# ---------------- Batch 8: final niceties ----------------
say "Re-applying wallpaper fallback and ensuring services are OK."
mkdir -p "$HOME/.config/wallpapers"
# If the repo shipped a fallback, leave it; otherwise touch a blank file so Hyprpaper won’t choke.
[[ -f "$HOME/.config/wallpapers/caelestia-fallback.png" ]] || convert -size 1920x1080 xc:#101216 "$HOME/.config/wallpapers/caelestia-fallback.png" 2>/dev/null || true

say "All batches done."
echo
echo "Next steps:"
echo "  1) reboot"
echo "  2) in SDDM, pick 'Hyprland' and log in"
echo "If you land on a blank screen with cursor, press Super+Enter to open Kitty, then run:"
echo "  swww init && swww img ~/.config/wallpapers/caelestia-fallback.png"
echo "  pkill waybar && waybar &"
echo
say "Done. Logs saved to: $RUN_LOG"