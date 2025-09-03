#!/usr/bin/env bash
set -euo pipefail

echo "== Caelestia AMD/Wayland one-shot repair =="
[ "$(id -u)" -eq 0 ] && { echo "Please run as your normal user (it will sudo when needed)."; exit 1; }

# ---------- 0) helpers ----------
sudo_tee() { sudo tee "$1" >/dev/null; }

# ---------- 1) Enable multilib (for lib32-vulkan-radeon) ----------
PACCONF="/etc/pacman.conf"
if ! grep -qE '^\[multilib\]' "$PACCONF"; then
  echo "!! [multilib] section not found in $PACCONF — this Arch install looks unusual."
else
  if awk 'BEGIN{p=0} /^\[multilib\]/{p=1} /^\[/{if($0!~"^\[multilib\\]")p=0} {if(p&&$0~/^#?Include =/){print "HAVEINC"; exit}}' "$PACCONF" | grep -q HAVEINC; then
    if grep -qE '^\s*#\s*\[multilib\]' "$PACCONF"; then
      echo "[*] Enabling multilib in $PACCONF (creating backup)…"
      sudo cp -n "$PACCONF" "$PACCONF.$(date +%Y%m%d%H%M%S).bak"
      # Uncomment the block
      sudo sed -i '/^\s*#\s*\[multilib\]/{s/#\s*\[multilib\]/[multilib]/;n;s/#\s*Include/Include/}' "$PACCONF"
    fi
  fi
fi

echo "[*] Syncing pacman db…"
sudo pacman -Sy --noconfirm

# ---------- 2) Install AMD + Vulkan stack ----------
echo "[*] Installing AMD/Mesa/Vulkan (safe if already installed)…"
sudo pacman -S --needed --noconfirm \
  mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
  vulkan-tools mesa-utils swww curl

# ---------- 3) Minimal wallpaper + swww ----------
mkdir -p "$HOME/Pictures"
WP="$HOME/Pictures/archlinux_logo.png"
if [ ! -s "$WP" ]; then
  echo "[*] Fetching a tiny wallpaper to avoid 'missing wallpaper' warnings…"
  curl -fsSL -o "$WP" https://raw.githubusercontent.com/archlinux/archinstall/main/archinstall/assets/archlinux-logo-dark-scaled.png || true
fi

# start swww if not running (ignore errors if already managed by your hypr config)
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  echo "[*] Starting swww-daemon…"
  swww init || true
fi
# set a wallpaper (won’t crash if it fails)
swww img "$WP" --transition-type none >/dev/null 2>&1 || true

# ---------- 4) Quick sanity check of GPU stack (non-fatal) ----------
echo "[i] Vulkan device summary:"
vulkaninfo 2>/dev/null | sed -n '1,120p' | sed -n 's/.*deviceName.*/  &/p' || true

# ---------- 5) Run Caelestia from Nix with Wayland + flakes ----------
echo
echo "[*] Launching Caelestia via Nix (Wayland)…"
export QT_QPA_PLATFORM=wayland
export NIX_CONFIG="extra-experimental-features = nix-command flakes"
# If you previously installed caelesia system-wide, leaving it; Nix run will use its own build.
nix run github:caelestia-dots/shell

echo
echo "== Done =="
echo "If you still see 'Failed to create RHI/OpenGL context':"
echo "  • Reboot once (kernel/driver reload)"
echo "  • Then run:  QT_QPA_PLATFORM=wayland nix run github:caelestia-dots/shell"