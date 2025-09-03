bash -euo pipefail <<'EOF'
echo "== Caelestia quick-fix: AMD graphics + wallpaper =="

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }
pkg() { sudo pacman -Sy --needed --noconfirm "$@"; }

# ---------- sanity: Arch only ----------
if ! have pacman; then
  echo "This script is for Arch/Arch-based systems (needs pacman)." >&2
  exit 1
fi

# ---------- detect AMD GPU ----------
GPU_LINE="$(lspci -nnk | grep -Ei 'VGA|3D|Display' | grep -Ei 'AMD|ATI' || true)"
if [ -n "$GPU_LINE" ]; then
  echo "[GPU] Detected AMD/ATI GPU:"
  echo "      $GPU_LINE"
  AMD=1
else
  echo "[GPU] AMD GPU not detected. I’ll still install Mesa/Vulkan in case it’s hybrid."
  AMD=0
fi

# ---------- drivers & tools ----------
echo "[PKG] Installing graphics drivers & tools…"
pkg mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-tools mesa-utils

echo "[PKG] Installing wallpaper helpers…"
pkg swww imagemagick

# ---------- wallpaper: ensure ~/Pictures/wallpaper.png exists ----------
WP_DIR="$HOME/Pictures"
WP="$WP_DIR/wallpaper.png"
mkdir -p "$WP_DIR"

if [ ! -f "$WP" ]; then
  echo "[WP] No ~/Pictures/wallpaper.png found. Creating one…"
  # 1) Try to copy a system background
  SYS_BG="$(find /usr/share/backgrounds /usr/share/pixmaps -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | head -n1 || true)"
  if [ -n "$SYS_BG" ]; then
    cp -f "$SYS_BG" "$WP"
    echo "[WP] Copied system image -> $WP"
  else
    # 2) Generate a simple gradient placeholder with ImageMagick
    convert -size 1920x1080 gradient:'#101216-#2a2f39' -gravity center -pointsize 64 -fill '#ffffff' \
            -font DejaVu-Sans -annotate +0+0 'Caelestia' "$WP" || {
      echo "[WP] Could not generate placeholder; creating a 1px PNG."
      printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\nIDATx\x9cc`\x00\x00\x00\x02\x00\x01\xe2!\xbc3\x00\x00\x00\x00IEND\xaeB`\x82' > "$WP"
    }
    echo "[WP] Generated -> $WP"
  fi
else
  echo "[WP] Found existing wallpaper: $WP"
fi

# ---------- start swww & set wallpaper ----------
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  echo "[SWWW] Starting swww-daemon…"
  swww init || true
fi

echo "[SWWW] Setting wallpaper…"
swww img "$WP" --transition-type any --transition-step 90 --transition-fps 60 || true

# ---------- quick health checks ----------
echo
echo "== Quick GL/Vulkan check =="
if have glxinfo; then
  glxinfo -B | sed -n '1,20p'
else
  echo "glxinfo not found (mesa-utils should have installed it)."
fi

if have vulkaninfo; then
  echo
  vulkaninfo 2>/dev/null | sed -n '1,40p'
else
  echo
  echo "vulkaninfo not found (vulkan-tools should have installed it)."
fi

echo
echo "== Done =="
echo "If you were seeing 'Failed to initialize graphics backend' or 'No wallpaper page found',"
echo "they should be gone now. Re-run Caelestia:"
echo
echo "  nix run github:caelestia-dots/shell"
echo
echo "or your local launcher:"
echo "  caelestia-shell"
EOF