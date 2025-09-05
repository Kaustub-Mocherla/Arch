#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "This script is for Arch/Arch-based systems only."; exit 1
fi
if [[ $EUID -eq 0 ]]; then
  echo "Run as normal user (script will sudo as needed)."; exit 1
fi

echo "==> Full system sync"
sudo pacman -Syu --noconfirm

echo "==> Install Hyprland + deps"
sudo pacman -S --needed --noconfirm \
  hyprland hyprpaper waybar wofi kitty mako \
  swww grim slurp swappy \
  thunar gvfs gvfs-mtp gvfs-smb \
  pipewire pipewire-pulse wireplumber \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  xdg-desktop-portal-hyprland qt5-wayland qt6-wayland wl-clipboard \
  brightnessctl playerctl \
  ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji

# GPU drivers (best-effort)
GPU_INFO="$(lspci -nnk | grep -E 'VGA|3D|Display' || true)"
echo "==> GPU: $GPU_INFO"
if grep -qi nvidia <<<"$GPU_INFO"; then
  sudo pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
  mkdir -p "$HOME/.config/hypr"
  grep -q "WLR_NO_HARDWARE_CURSORS" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null || \
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HOME/.config/hypr/hyprland.conf"
elif grep -qiE "AMD|ATI" <<<"$GPU_INFO"; then
  sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver
elif grep -qi intel <<<"$GPU_INFO"; then
  sudo pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver
fi

echo "==> Ensure Hyprland Wayland session entry"
sudo mkdir -p /usr/share/wayland-sessions
# If a manual file exists, let the package version win
if [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
  sudo pacman -S --noconfirm hyprland --overwrite usr/share/wayland-sessions/hyprland.desktop
fi
# Force the robust Exec line
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF

echo "==> Prepare Hypr config; disable crashing autostarts"
mkdir -p "$HOME/.config/hypr"
CFG="$HOME/.config/hypr/hyprland.conf"
TS=$(date +%Y%m%d-%H%M%S)
if [[ -f "$CFG" ]]; then
  cp -a "$CFG" "$CFG.bak.$TS"
else
  cat > "$CFG" <<'EOF'
# Minimal safe Hypr config (created by script)
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
# Add your Caelestia config later below
EOF
fi

# Comment out all exec-once lines temporarily
if grep -q 'exec-once' "$CFG"; then
  sed -i 's/^\s*exec-once\s*=/## disabled-by-script: exec-once =/g' "$CFG"
fi

# Provide helper to re-enable them later
RE_EN="$HOME/.local/bin/enable_exec_once.sh"
mkdir -p "$HOME/.local/bin"
cat > "$RE_EN" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CFG="$HOME/.config/hypr/hyprland.conf"
if [[ ! -f "$CFG" ]]; then echo "No hyprland.conf found"; exit 1; fi
cp -a "$CFG" "$CFG.reenable.bak.$(date +%Y%m%d-%H%M%S)"
# Un-comment the lines we previously disabled
sed -i 's/^## disabled-by-script: exec-once =/exec-once =/g' "$CFG"
echo "Re-enabled exec-once lines. Run: hyprctl reload -r"
EOS
chmod +x "$RE_EN"

echo "==> Enable core services (NetworkManager, Bluetooth, SDDM)"
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth || true
sudo systemctl enable sddm

echo "==> Permissions sanity"
sudo chown -R "$USER:$USER" "$HOME"
chmod 700 "$HOME"

cat <<EOM

============================================================
Done.

NEXT:
1) Reboot:   sudo reboot
2) In SDDM -> choose "Hyprland" session and log in.
   (Autostarts are temporarily disabled to prevent crashes.)
3) Once stable, re-enable autostarts:
     $RE_EN
   then inside Hyprland:
     hyprctl reload -r

If you get bounced back to SDDM, check:
  tail -n 200 ~/.local/share/sddm/wayland-session.log
Or try from TTY:
  dbus-run-session /usr/bin/Hyprland

You can restore your original config from:
  $CFG.bak.$TS
============================================================
EOM