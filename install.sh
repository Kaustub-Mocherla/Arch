#!/usr/bin/env bash
# End-4 Hyprland clean installer for Arch (with cooling + conflict fixes)

set -euo pipefail
LOG="$HOME/end4_install_$(date +%F_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

say(){ printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
cool(){
  local MAX="${MAX_TEMP:-80}"                         # change with: MAX_TEMP=75 ./install_end4_hypr.sh
  local EVERY="${CHECK_EVERY:-15}"                    # seconds
  while command -v sensors >/dev/null 2>&1; do
    local T
    T=$(sensors 2>/dev/null | awk '/^Package id 0:|^Tctl:|^Tdie:|^temp1:/{gsub(/\+|°C|°/,"",$2); sub(/\..*/,"",$2); print $2; exit}')
    [[ -z "$T" ]] && break
    if (( T >= MAX )); then
      echo "CPU temp ${T}°C ≥ ${MAX}°C — pausing… (Ctrl+C to abort)"; sleep "$EVERY"; continue
    fi
    break
  done
}

need(){
  local pkgs=( "$@" )
  say "Installing: ${pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}" || true
  cool
}

# -------------------- PREP --------------------
say "Refreshing keys/repos"; sudo pacman -Sy --noconfirm || true; cool

say "Remove known conflicts / leftovers"
sudo pacman -R --noconfirm swww 2>/dev/null || true
rm -rf "$HOME/.local/share/caelestia" "$HOME/.local/share/sddm" 2>/dev/null || true

say "Install base tools"
need git rsync curl wget base-devel lm_sensors fish nano

# ensure yay (AUR)
if ! command -v yay >/dev/null 2>&1; then
  say "Installing yay (AUR helper)…"
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# -------------------- CORE DESKTOP --------------------
# Batch 1: compositor + portals
need hyprland xdg-desktop-portal-hyprland xdg-desktop-portal polkit-gnome

# Batch 2: bar/launcher/terminal/notify + wallpaper
say "Installing swww-git from AUR (with yay)…"; yay -S --needed --noconfirm swww-git || true; cool
need waybar wofi kitty mako hyprpaper wl-clipboard grimblast brightnessctl network-manager-applet

# Batch 3: audio + fonts + helpers
need pipewire wireplumber pipewire-alsa pipewire-pulse qt6ct qt5ct noto-fonts ttf-jetbrains-mono ttf-font-awesome imagemagick

# -------------------- END-4 DOTS --------------------
REPO_DIR="$HOME/.local/share/end4"
CFG_BAK="$HOME/.config_backup_end4_$(date +%F_%H%M%S)"
DOTS_DIR="$REPO_DIR/dots-hyprland"

say "Cloning End-4 dots…"
mkdir -p "$REPO_DIR"
if [[ -d "$DOTS_DIR/.git" ]]; then
  (cd "$DOTS_DIR" && git pull --ff-only)
else
  git clone https://github.com/End-4/dots-hyprland "$DOTS_DIR"
fi
cool

say "Backing up ~/.config → $CFG_BAK"
mkdir -p "$CFG_BAK"
rsync -a --delete --mkpath "$HOME/.config/" "$CFG_BAK/" || true

say "Copying End-4 configs into ~/.config (force-merge, no non-dir errors)"
# End-4 repo uses a top-level 'config' folder:
if [[ -d "$DOTS_DIR/config" ]]; then
  rsync -a --mkpath "$DOTS_DIR/config/" "$HOME/.config/"
fi

# -------------------- SAFE AUTOSTART (guaranteed visibility) --------------------
mkdir -p "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/wallpapers"

# Fallback wallpaper
if [[ ! -f "$HOME/.config/wallpapers/end4-fallback.png" ]]; then
  convert -size 1920x1080 xc:"#101216" "$HOME/.config/wallpapers/end4-fallback.png" 2>/dev/null \
  || touch "$HOME/.config/wallpapers/end4-fallback.png"
fi

# Minimal Waybar if repo didn’t provide one
if [[ ! -s "$HOME/.config/waybar/config" && ! -s "$HOME/.config/waybar/config.jsonc" ]]; then
  cat >"$HOME/.config/waybar/config.jsonc" <<'JSON'
{
  "layer":"top","height":30,
  "modules-left":["clock"],"modules-center":[],
  "modules-right":["network","pulseaudio","cpu","memory","temperature","battery"],
  "network":{"format-wifi":"{essid} {signalStrength}%"},
  "temperature":{"critical-threshold":90},
  "battery":{"format":"{capacity}%"}
}
JSON
  echo '*{font-family:"JetBrainsMono Nerd Font","Noto Sans";font-size:12px}' > "$HOME/.config/waybar/style.css"
fi

HYPR="$HOME/.config/hypr/hyprland.conf"
touch "$HYPR"
awk '
/^# --- AUTOSTART BEGIN ---/{skip=1}
/^# --- AUTOSTART END ---/{skip=0; next}
!skip{print}
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
print "exec-once = swww img ~/.config/wallpapers/end4-fallback.png"
print "exec-once = waybar"
print "bind = SUPER, RETURN, exec, kitty"
print "bind = SUPER, D, exec, wofi --show drun"
print "bind = SUPER SHIFT, R, exec, hyprctl reload"
print "# --- AUTOSTART END ---"
}' "$HYPR" > "$HYPR.tmp" && mv "$HYPR.tmp" "$HYPR"

# -------------------- SESSION & DISPLAY MANAGER --------------------
say "Ensuring Hyprland Wayland session entry"
sudo install -Dm644 /dev/stdin /usr/share/wayland-sessions/hyprland.desktop <<'DESK'
[Desktop Entry]
Name=Hyprland (End-4)
Comment=Hyprland Wayland session
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
DESK

say "Enable SDDM (Wayland)"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/wayland.conf >/dev/null <<'CFG'
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=/usr/bin/kwin_wayland --no-global-shortcuts --locale1
SessionCommand=/usr/share/sddm/scripts/wayland-session
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QT_QPA_PLATFORM=wayland
CFG
sudo systemctl enable sddm.service

say "Done."
echo "Log file: $LOG"
echo
echo "Now: reboot → choose **Hyprland (End-4)** in SDDM → login."
echo "If screen is blank, press Super+Enter (kitty) and run:"
echo "  swww init && swww img ~/.config/wallpapers/end4-fallback.png"
echo "  pkill waybar; waybar &"