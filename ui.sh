#!/bin/bash
set -euo pipefail

echo "=== Installing end-4/dots-hyprland ==="

# --- Step 1. Backup old configs (Caelestia or others) ---
BACKUP_DIR="$HOME/.config_backup_end4_$(date +%F_%H%M%S)"
echo ">>> Backing up current configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r "$HOME/.config/"* "$BACKUP_DIR"/ 2>/dev/null || true

# --- Step 2. Install additional packages (skip already installed ones) ---
echo ">>> Installing additional dependencies..."
sudo pacman -S --needed --noconfirm \
  jq polkit-gnome grim slurp wl-clipboard imagemagick \
  ttf-font-awesome ttf-jetbrains-mono noto-fonts \
  playerctl brightnessctl

# Some end-4 extras are in AUR: grimblast, hyprpicker
if ! command -v yay >/dev/null 2>&1; then
  echo ">>> Installing yay (AUR helper)..."
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir"/yay
  pushd "$tmpdir"/yay >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf "$tmpdir"
fi

echo ">>> Installing AUR extras..."
yay -S --needed --noconfirm grimblast hyprpicker

# --- Step 3. Clone or update repo ---
cd "$HOME"
if [[ -d "dots-hyprland" ]]; then
  echo ">>> Repo exists, updating..."
  cd dots-hyprland
  git pull
else
  echo ">>> Cloning end-4/dots-hyprland..."
  git clone https://github.com/end-4/dots-hyprland.git
  cd dots-hyprland
fi

# --- Step 4. Copy configs ---
echo ">>> Installing configs into ~/.config"
cp -r config/* "$HOME/.config/"

# --- Step 5. Enable required services (already mostly done in Caelestia) ---
echo ">>> Ensuring services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth || true
sudo systemctl enable sddm

# --- Step 6. Final message ---
echo "===================================="
echo "✅ Installed end-4/dots-hyprland"
echo "Configs are in ~/.config"
echo "Backup of old configs is in $BACKUP_DIR"
echo "Now reboot and choose Hyprland in SDDM."
echo "===================================="