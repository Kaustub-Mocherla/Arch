#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
have(){ command -v "$1" >/dev/null 2>&1; }
pkg(){ sudo pacman -S --needed --noconfirm "$@"; }

USER_NAME="${USER}"
BACKUP="$HOME/.config_backup_end4_$(date +%F_%H%M%S)"
REPO_DIR="$HOME/dots-hyprland"

echo "==> end-4/dots-hyprland one-shot installer"
echo "Log: $HOME/end4_install_$(date +%F_%H%M%S).log"

# ---------- core packages (most already on your PC) ----------
echo "==> Installing/refreshing core packages (pacman)"
pkg git base-devel jq polkit-gnome wl-clipboard grim slurp \
    playerctl brightnessctl imagemagick \
    hyprland waybar wofi kitty mako \
    pipewire pipewire-pulse wireplumber \
    xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome

# Services you already use; ensure enabled
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true
sudo systemctl enable sddm || true

# ---------- AUR helper + AUR deps ----------
if ! have yay; then
  echo "==> Installing yay (AUR helper)…"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  ( cd "$tmp/yay" && makepkg -si --noconfirm )
fi

echo "==> Installing AUR extras (grimblast, hyprpicker)"
yay -S --needed --noconfirm grimblast hyprpicker

# ---------- backup current configs ----------
echo "==> Backing up current ~/.config to: $BACKUP"
mkdir -p "$BACKUP"
cp -r "$HOME/.config/." "$BACKUP/" 2>/dev/null || true

# ---------- clone or update repo ----------
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "==> Repo exists, pulling latest…"
  git -C "$REPO_DIR" pull --ff-only
else
  echo "==> Cloning end-4/dots-hyprland…"
  git clone https://github.com/end-4/dots-hyprland.git "$REPO_DIR"
fi

# ---------- install dotfiles (from .config/, not config/) ----------
echo "==> Copying configs from repo’s .config/ into ~/.config/"
if [[ -d "$REPO_DIR/.config" ]]; then
  mkdir -p "$HOME/.config"
  cp -rT "$REPO_DIR/.config" "$HOME/.config"
else
  echo "ERROR: '$REPO_DIR/.config' not found. Repo layout changed?"
  exit 1
fi

# ---------- small quality-of-life fixes ----------
# Add user to 'input' group to silence Waybar /dev/input warnings
if ! id -nG "$USER_NAME" | grep -qw input; then
  echo "==> Adding $USER_NAME to 'input' group (relog required)"
  sudo usermod -aG input "$USER_NAME"
fi

# Try to fix Waybar battery name if config references BATX
BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep '^BAT' | head -n1 || true)
if [[ -n "${BAT:-}" ]] && ls "$HOME/.config/waybar"/config* >/dev/null 2>&1; then
  for f in "$HOME/.config/waybar"/config*; do
    sed -i "s/\"BAT[0-9]\"/\"$BAT\"/g; s/\"bat[0-9]\"/\"$BAT\"/g" "$f" || true
  done
fi

# Ensure Hyprland session file exists (SDDM)
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

echo
echo "==================== DONE ===================="
echo "✅ end-4/dots-hyprland installed."
echo "• Backup created:  $BACKUP"
echo "• Repo location:   $REPO_DIR"
echo "• If this is your first time in the 'input' group, reboot to apply."
echo "Next:"
echo "  1) reboot"
echo "  2) at SDDM select: Hyprland"
echo "  3) log in and enjoy the end-4 setup"
echo "================================================"