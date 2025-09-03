bash -euo pipefail <<'EOF'
echo "== AMD + Vulkan + Caelestia (Nix) fix =="
echo "• This will install Mesa/Vulkan drivers, set env vars, and prep wallpaper."

# --- 0) Quick sanity ---
if ! command -v pacman >/dev/null; then
  echo "This script is for Arch/Arch-based systems (needs pacman). Aborting."
  exit 1
fi

# --- 1) Packages: AMD/Mesa/Vulkan + tools + helpers ---
echo "[1/6] Installing graphics drivers & tools…"
sudo pacman -Syu --needed --noconfirm \
  mesa lib32-mesa \
  vulkan-radeon lib32-vulkan-radeon \
  vulkan-icd-loader lib32-vulkan-icd-loader \
  libva-mesa-driver lib32-libva-mesa-driver \
  vulkan-tools mesa-demos \
  swww wl-clipboard curl unzip

# (Optional but harmless) Wayland/Qt pieces that help shells
sudo pacman -S --needed --noconfirm qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools || true

# --- 2) Persist environment that helps RADV/Qt on Wayland ---
echo "[2/6] Writing persistent graphics env to ~/.config/environment.d/99-amd-qs.conf"
mkdir -p "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/99-amd-qs.conf" <<'ENVV'
# Prefer Wayland + RADV (AMD)
QT_QPA_PLATFORM=wayland
LIBGL_ALWAYS_SOFTWARE=0
MESA_LOADER_DRIVER_OVERRIDE=radeonsi
RADV_PERFTEST=aco
# Point Vulkan ICDs explicitly to AMD (RADV)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
ENVV

# Shell session pick-up (won’t affect already-running processes)
echo "   -> Log out/in (or reboot) to fully apply persistent env."

# Also export for *this* shell so we can test immediately:
export QT_QPA_PLATFORM=wayland
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export RADV_PERFTEST=aco
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json

# --- 3) Vulkan check ---
echo "[3/6] Checking Vulkan runtime…"
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary 2>/dev/null | sed -n '1,200p' || true
else
  echo "   (vulkaninfo missing? pacman should have installed it — continue anyway.)"
fi

# --- 4) Wallpaper: make something available & start swww ---
echo "[4/6] Ensuring a wallpaper exists and swww is running…"
mkdir -p "$HOME/Pictures"
# Try to source a system wallpaper if none in Pictures
if ! find "$HOME/Pictures" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | grep -q .; then
  for d in /usr/share/backgrounds /usr/share/wallpapers /usr/share/pixmaps; do
    if [ -d "$d" ]; then
      cp -n "$d"/*.{jpg,jpeg,png} "$HOME/Pictures/" 2>/dev/null || true
    fi
  done
fi

# Start swww if needed
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init || true
fi

# Set first found wallpaper (no error if none found)
WIMG="$(find "$HOME/Pictures" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | head -n1 || true)"
if [ -n "${WIMG:-}" ]; then
  swww img "$WIMG" --transition-type any || true
  echo "   -> Wallpaper set to: $WIMG"
else
  echo "   -> No image found in ~/Pictures; Caelestia will show 'Wallpaper missing?'."
fi

# --- 5) Nix wrapper: run Caelestia with correct env each time ---
echo "[5/6] Creating launcher wrapper for Nix Caelestia…"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-nix" <<'RUNN'
#!/usr/bin/env bash
set -euo pipefail
# Ensure helpful env for AMD + Wayland
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export RADV_PERFTEST=aco
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
# Hint for Qt Quick to use GLES (often avoids desktop GL issues)
export QSG_RHI_BACKEND=gles
# Run Caelestia shell from GitHub via Nix
exec nix run github:caelestia-dots/shell -- "$@"
RUNN
chmod +x "$HOME/.local/bin/caelestia-nix"
echo "   -> Use:  caelestia-nix"

# --- 6) One-shot test run suggestion ---
echo "[6/6] Done."
echo
echo "Next steps:"
echo "  • Reboot (best) or log out/in so the environment.d vars are active system-wide."
echo "  • Then launch Caelestia via Nix with:"
echo "      caelestia-nix"
echo
echo "If you STILL see 'Failed to create graphics context' after reboot:"
echo "  • Run:  glxinfo -B   (from mesa-demos) and share the output line 'OpenGL renderer string'"
echo "  • Run:  vulkaninfo --summary | sed -n '1,120p'"
EOF