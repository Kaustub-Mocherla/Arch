bash -euo pipefail <<'EOF'
# === Arch AMD Vulkan + multilib + Chrome (one-shot) ==========================
echo "[0] Starting… (need sudo for pacman changes)"
sudo -v

PACCONF="/etc/pacman.conf"
BACKUP="/etc/pacman.conf.$(date +%Y%m%d-%H%M%S).bak"

echo "[1] Ensure [multilib] repo is enabled (backup: $BACKUP)…"
# Backup once
sudo cp -n "$PACCONF" "$BACKUP" || true

# Uncomment the multilib block if it's still commented
if grep -q '^\s*\[multilib\]' "$PACCONF"; then
  echo "    - multilib already enabled."
else
  # Typical commented block:
  # [multilib] is commented as "#[multilib]" on some systems,
  # and the Include line as "#Include = /etc/pacman.d/mirrorlist"
  sudo sed -i \
    -e 's/^\s*#\s*\[multilib\]/[multilib]/' \
    -e 's|^\s*#\s*Include\s*=\s*/etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|' \
    "$PACCONF"
  echo "    - multilib block uncommented."
fi

echo "[2] Force sync & update package databases…"
sudo pacman -Syyu --noconfirm

echo "[3] Install AMD Vulkan drivers & graphics tools…"
# Core drivers + 32-bit, and tools for verification
sudo pacman -S --needed --noconfirm \
  vulkan-radeon lib32-vulkan-radeon \
  mesa lib32-mesa libva-mesa-driver lib32-libva-mesa-driver \
  vulkan-tools mesa-demos

echo "[4] Quick driver check (lspci)…"
lspci | grep -E "VGA|3D|Display" || true

echo "[5] Verify Vulkan/GL — saving short reports to ~/gpu-diagnostics/"
OUTDIR="$HOME/gpu-diagnostics"
mkdir -p "$OUTDIR"
# Vulkan summary (this prints errors to stdout too if any)
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary 2>&1 | tee "$OUTDIR/vulkaninfo-summary.txt" | head -n 50
else
  echo "vulkaninfo not found (vulkan-tools should have installed it)" | tee "$OUTDIR/vulkaninfo-summary.txt"
fi

# OpenGL / renderer info
if command -v glxinfo >/dev/null 2>&1; then
  glxinfo -B 2>&1 | tee "$OUTDIR/glxinfo-B.txt"
else
  echo "glxinfo not found (mesa-demos should have installed it)" | tee "$OUTDIR/glxinfo-B.txt"
fi

echo "[6] Browser: install Google Chrome if AUR helper exists, else Chromium…"
if command -v yay >/dev/null 2>&1; then
  echo "    - Using yay to install google-chrome (AUR)…"
  yay -S --needed --noconfirm google-chrome
elif command -v paru >/dev/null 2>&1; then
  echo "    - Using paru to install google-chrome (AUR)…"
  paru -S --needed --noconfirm google-chrome
else
  echo "    - No AUR helper found. Installing Chromium from official repos."
  sudo pacman -S --needed --noconfirm chromium
fi

echo
echo "=== Done ==="
echo "Diagnostics saved to: $OUTDIR"
echo "If you were seeing 'Failed to initialize graphics backend' before, try re-running your Caelestia/Hyprland session."
echo "Tip: reboot once after new GPU drivers, then try:  nix run github:caelestia-dots/shell  or your  caelestia-shell  launcher."
EOF