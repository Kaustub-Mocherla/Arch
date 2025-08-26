#!/usr/bin/env bash
# Arch Linux one-shot installer for Hyprland + Caelestia Shell
# Run this from a TTY as your normal user (not root) with sudo available.

set -euo pipefail

### Helpers
ok(){ echo -e "\033[1;32m[✓]\033[0m $*"; }
info(){ echo -e "\033[1;36m[i]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[!]\033[0m $*"; }
die(){ echo -e "\033[1;31m[x]\033[0m $*" >&2; exit 1; }

if [[ $EUID -eq 0 ]]; then
  die "Run this as your USER, not root. Use sudo when asked."
fi

### Step 1: Update system
info "Updating system…"
sudo pacman -Syu --noconfirm

### Step 2: Install Hyprland + Wayland essentials
info "Installing Hyprland and Wayland essentials…"
sudo pacman -S --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland \
  wl-clipboard polkit-kde-agent \
  waybar alacritty grim swappy \
  pipewire wireplumber pipewire-alsa pipewire-pulse

ok "Hyprland + essentials installed."

### Step 3: Install AUR helper (yay) if missing
if ! command -v yay >/dev/null; then
  info "Installing yay (AUR helper)…"
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  cd "$tmpdir/yay-bin"
  makepkg -si --noconfirm
  cd ~
  rm -rf "$tmpdir"
  ok "yay installed."
fi

### Step 4: Install Quickshell + Caelestia deps
info "Installing Caelestia dependencies (AUR + repo)…"
sudo pacman -S --needed --noconfirm \
  base-devel git curl wget ddcutil brightnessctl cava lm_sensors fish qt6-declarative libpipewire libqalculate

yay -S --needed --noconfirm quickshell-git caelestia-cli-git \
  ttf-caskaydia-cove-nerd ttf-material-symbols || true

ok "Caelestia dependencies installed."

### Step 5: Clone Caelestia Shell
info "Cloning Caelestia Shell repo…"
mkdir -p ~/.config/quickshell
if [[ -d ~/.config/quickshell/caelestia ]]; then
  cd ~/.config/quickshell/caelestia && git pull
else
  git clone https://github.com/caelestia-dots/shell.git ~/.config/quickshell/caelestia
fi
ok "Caelestia Shell is in ~/.config/quickshell/caelestia"

### Step 6: Autostart Caelestia in Hyprland
info "Configuring Hyprland autostart for Caelestia…"
mkdir -p ~/.config/caelestia
mkdir -p ~/.config/hypr
HYPR_USER_CONF=~/.config/caelestia/hypr-user.conf
if ! grep -q "qs -c caelestia" "$HYPR_USER_CONF" 2>/dev/null; then
  echo 'exec-once = qs -c caelestia' >> "$HYPR_USER_CONF"
  ok "Added Caelestia autostart to $HYPR_USER_CONF"
else
  ok "Caelestia autostart already present."
fi

### Step 7: Install & enable SDDM (login manager)
info "Installing and enabling SDDM (login manager)…"
sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable --now sddm

ok "SDDM enabled. At next boot, choose Hyprland session."

### Step 8: Final message
cat <<'EOF'

========================================================
🎉 Installation complete!

➡️ On reboot, you will see SDDM (login screen).
➡️ Choose "Hyprland" as the session and log in.

Caelestia Shell will autostart, giving you the full UI.
If you just want to test right now (without reboot):

  1. Log in to your TTY as user
  2. Run:
       Hyprland
  3. Inside Hyprland, Caelestia will autostart.

Enjoy your Caelestia desktop!
========================================================
EOF