#!/usr/bin/env bash
set -euo pipefail

# --- Safety checks ---
if ! command -v pacman >/dev/null 2>&1; then
  echo "This script is for Arch/Arch-based systems (uses pacman). Exiting."
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  echo "Please run as a normal user (the script will use sudo)."
  exit 1
fi

# --- Helpers ---
install_pkgs() {
  sudo pacman -S --needed --noconfirm "$@"
}

echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Installing core packages (Hyprland, portals, tools, SDDM)..."
install_pkgs hyprland xdg-desktop-portal-hyprland wl-clipboard \
             qt5-wayland qt6-wayland polkit \
             waybar wofi grim slurp \
             sddm

# --- GPU drivers (best-effort detection) ---
GPU_INFO="$(lspci -nnk | grep -E "VGA|3D|Display" || true)"
echo "==> Detected GPU: $GPU_INFO"

if echo "$GPU_INFO" | grep -qi nvidia; then
  echo "==> Installing NVIDIA drivers..."
  install_pkgs nvidia nvidia-utils nvidia-settings
  # Add a safe env tweak for cursors on some NVIDIA setups
  mkdir -p "$HOME/.config/hypr"
  if ! grep -q "WLR_NO_HARDWARE_CURSORS" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null; then
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HOME/.config/hypr/hyprland.conf" || true
  fi
elif echo "$GPU_INFO" | grep -qiE "AMD|ATI"; then
  echo "==> Installing AMD/Mesa drivers..."
  install_pkgs mesa vulkan-radeon libva-mesa-driver
elif echo "$GPU_INFO" | grep -qi intel; then
  echo "==> Installing Intel/Mesa drivers..."
  install_pkgs mesa vulkan-intel intel-media-driver
else
  echo "==> Unknown GPU vendor; skipping vendor-specific drivers."
fi

# --- SDDM Hyprland session entry ---
echo "==> Creating Hyprland Wayland session for SDDM..."
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

# --- Minimal Hypr config (only if you don't already have one) ---
if [[ ! -d "$HOME/.config/hypr" ]] || [[ ! -s "$HOME/.config/hypr/hyprland.conf" ]]; then
  echo "==> Installing a minimal, safe Hyprland config (non-destructive)..."
  mkdir -p "$HOME/.config/hypr"
  cat > "$HOME/.config/hypr/hyprland.conf" <<'EOF'
# Minimal safe Hyprland config (you can replace with Caelestia configs later)
monitor=,preferred,auto,1
input {
  kb_layout = us
}
# Basic utilities (Waybar + app launcher). Comment these if Caelestia handles them.
exec-once = waybar &
exec-once = wofi --show drun &
# Tiling defaults
general {
  gaps_in = 5
  gaps_out = 10
}
EOF
else
  echo "==> Existing Hypr config found; not overwriting."
fi

# --- Permissions sanity (common SDDM gotcha) ---
echo "==> Ensuring sane home permissions..."
sudo chown -R "$USER:$USER" "$HOME"
chmod 700 "$HOME"

# --- Enable SDDM ---
echo "==> Enabling SDDM..."
sudo systemctl enable sddm.service

echo
echo "============================================================"
echo "All set! Next steps:"
echo "1) Reboot: sudo reboot"
echo "2) At the SDDM login screen, pick the 'Hyprland' session."
echo "3) Log in. You should land in Hyprland (Caelestia configs will load if present)."
echo
echo "If you get bounced back to SDDM, switch to TTY (Ctrl+Alt+F2) and run:"
echo "  tail -n 200 ~/.local/share/sddm/wayland-session.log"
echo "============================================================"