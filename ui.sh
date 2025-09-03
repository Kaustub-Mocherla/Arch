#!/usr/bin/env bash
set -euo pipefail

# ---- config (change if you want) --------------------------------------------
WALLPAPER_CANDIDATES=(
  "$HOME/Pictures/Wallpapers"
  "$HOME/Pictures"
  "$HOME"
)
CE_CFG="$HOME/.config/quickshell/caelestia"
QS_QML_SYS="/usr/lib/qt6/qml"                 # system QML dir
# -----------------------------------------------------------------------------

say() { printf "\033[1;36m[fix]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[ok]\033[0m %s\n"  "$*"; }
warn(){ printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; exit 1; }

require_root_pkgs() {
  local pkgs=("$@")
  sudo pacman -Sy --needed --noconfirm "${pkgs[@]}"
}

build_aur_pkg() {
  local pkg="$1"
  local dir="$HOME/.cache/aur/$pkg"
  say "Building AUR: $pkg"
  mkdir -p "$dir"
  if [[ ! -d "$dir/.git" ]]; then
    git clone "https://aur.archlinux.org/$pkg.git" "$dir"
  else
    git -C "$dir" pull --ff-only || true
  fi
  ( cd "$dir" && makepkg -si --noconfirm --needed )
  ok "Installed AUR pkg: $pkg"
}

# ---- 0) sanity --------------------------------------------------------------
command -v git >/dev/null 2>&1 || die "git missing (unexpected)."
command -v pacman >/dev/null 2>&1 || die "This script is for Arch."

# ---- 1) AMD graphics stack (Mesa/OpenGL/Vulkan) -----------------------------
say "Installing AMD graphics stack (Mesa + Vulkan)…"
require_root_pkgs mesa libglvnd vulkan-radeon vulkan-icd-loader
# 32-bit libs are optional; only install if multilib is enabled
if grep -q "^\[multilib\]" /etc/pacman.conf; then
  require_root_pkgs lib32-mesa lib32-vulkan-radeon
else
  warn "Multilib not enabled; skipping 32-bit Mesa/Vulkan."
fi
ok "Graphics stack ready."

# ---- 2) handy tools you already use (idempotent) ----------------------------
say "Ensuring handy tools & fonts are present…"
require_root_pkgs curl unzip swww wl-clipboard grim slurp swappy playerctl pamixer noto-fonts ttf-liberation
ok "Tools/fonts ready."

# ---- 3) Google Chrome via AUR ----------------------------------------------
if ! command -v google-chrome >/dev/null 2>&1; then
  say "Installing Google Chrome from AUR…"
  require_root_pkgs base-devel
  build_aur_pkg google-chrome
else
  ok "Google Chrome already installed."
fi

# ---- 4) Wallpaper helper (swww) --------------------------------------------
say "Starting swww (Wayland wallpaper daemon) if needed…"
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init || warn "swww init failed (will rely on Caelestia wallpaper)."
else
  ok "swww already running."
fi

# Try to locate a wallpaper image to avoid 'missing wallpaper' screen
WP_FILE=""
for d in "${WALLPAPER_CANDIDATES[@]}"; do
  if [[ -d "$d" ]]; then
    WP_FILE="$(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -n1 || true)"
    [[ -n "$WP_FILE" ]] && break
  fi
done
if [[ -n "${WP_FILE:-}" ]]; then
  say "Found a wallpaper: $WP_FILE"
else
  warn "No wallpaper image found. You can put one in ~/Pictures."
fi

# ---- 5) Launch Caelestia via nix with proper env ---------------------------
# Requires nix with flakes+command enabled (you already set that).
say "Launching Caelestia (nix) with Wayland + QML path…"
export QT_QPA_PLATFORM=wayland
# Ensure Caelestia’s local qs modules are discoverable, if present
if [[ -d "$CE_CFG/modules/qs" ]]; then
  export QML2_IMPORT_PATH="$CE_CFG/modules/qs:${QML2_IMPORT_PATH-}"
fi
# Add system Qt6 QML dir as well (helps with some distros)
if [[ -d "$QS_QML_SYS" ]]; then
  export QML2_IMPORT_PATH="$QS_QML_SYS:${QML2_IMPORT_PATH-}"
fi

# Prefer your local config if it exists; otherwise nix will use packaged one.
EXTRA_ARGS=()
if [[ -n "${WP_FILE:-}" ]]; then
  EXTRA_ARGS+=( --wallpaper "$WP_FILE" )
fi

# Finally run it. If you want it to keep running after the script exits,
# start it in the background; otherwise leave foreground.
set +e
nix run github:caelestia-dots/shell -- "${EXTRA_ARGS[@]}"
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  warn "Caelestia (nix) exited with status $rc. Check the terminal logs above."
else
  ok "Caelestia started."
fi