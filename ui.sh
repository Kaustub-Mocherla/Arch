#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
have(){ command -v "$1" >/dev/null 2>&1; }
pkg_installed(){ pacman -Qi "$1" >/dev/null 2>&1; }
need_pkg(){ pkg_installed "$1" || sudo pacman -S --needed --noconfirm "$1"; }

# --- sanity ---
if ! have pacman; then echo "This script is for Arch-based systems."; exit 1; fi
if [[ $EUID -eq 0 ]]; then echo "Run as a normal user (uses sudo when needed)."; exit 1; fi

echo "==> Installing required tools"
# Core apps; imagemagick only for making a fallback wallpaper quickly
need_pkg waybar
need_pkg wofi
need_pkg kitty
need_pkg mako
need_pkg imagemagick || true

# Try to get swww with 'init' (prefer AUR swww-git)
SWWW_MODE="none"
if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
  SWWW_MODE="swww"
else
  echo "==> Installing swww (repo) first"
  sudo pacman -S --needed --noconfirm swww || true
  if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
    SWWW_MODE="swww"
  else
    echo "==> Repo swww lacks 'init'; trying AUR swww-git (yay/paru if present)"
    sudo pacman -R --noconfirm swww >/dev/null 2>&1 || true
    if have yay;  then yay  -S --needed --noconfirm swww-git || true
    elif have paru; then paru -S --needed --noconfirm swww-git || true
    fi
    if have swww && swww --help 2>/dev/null | grep -q '\binit\b'; then
      SWWW_MODE="swww"
    else
      echo "==> Using hyprpaper fallback"
      need_pkg hyprpaper
      SWWW_MODE="hyprpaper"
    fi
  fi
fi

# --- prepare config paths ---
CFG_DIR="$HOME/.config/hypr"
CFG="$CFG_DIR/hyprland.conf"
WPD="$HOME/.config/wallpapers"
mkdir -p "$CFG_DIR" "$WPD"

# Make a fallback wallpaper if none exist
if ! ls "$WPD"/* >/dev/null 2>&1; then
  echo "==> Creating fallback wallpaper"
  convert -size 3840x2160 gradient:'#1f1f28-#24283b' "$WPD/caelestia-fallback.png"
fi
WP_IMG="$(ls -1 "$WPD"/* | head -n1)"

# Create config if missing
if [[ ! -f "$CFG" ]]; then
  cat > "$CFG" <<'EOF'
monitor=,preferred,auto,1
input { kb_layout = us }
general { gaps_in = 5; gaps_out = 10 }
EOF
fi

# Backup once
TS=$(date +%Y%m%d-%H%M%S)
cp -a "$CFG" "$CFG.backup.$TS"

echo "==> Cleaning duplicates and writing a clean block"

# Remove existing conflicting exec-once lines & these keybinds
sed -i \
  -e '/^\s*exec-once\s*=\s*swww\b/d' \
  -e '/^\s*exec-once\s*=\s*hyprpaper\b/d' \
  -e '/^\s*exec-once\s*=\s*waybar\b/d' \
  -e '/^\s*exec-once\s*=\s*mako\b/d' \
  -e '/^\s*bind\s*=\s*SUPER,RETURN,exec,kitty\b/d' \
  -e '/^\s*bind\s*=\s*SUPER,SPACE,exec,wofi\b/d' \
  "$CFG"

# Append the clean block
{
  echo
  echo "### === AUTOSTART (managed by script) ==="
  if [[ "$SWWW_MODE" == "swww" ]]; then
    echo "exec-once = swww init"
    echo "exec-once = swww img $WP_IMG"
  else
    # hyprpaper fallback
    cat > "$CFG_DIR/hyprpaper.conf" <<EOF
preload = $WP_IMG
wallpaper = ,$WP_IMG
splash = false
EOF
    echo "exec-once = hyprpaper &"
  fi
  echo "exec-once = waybar"
  echo "exec-once = mako"

  echo
  echo "### === KEYBINDS (launcher/terminal) ==="
  echo "bind = SUPER,RETURN,exec,kitty"
  echo "bind = SUPER,SPACE,exec,wofi --show drun"
} >> "$CFG"

# NVIDIA cursor safety (harmless for others)
if lspci -nnk | grep -qi nvidia; then
  grep -q "WLR_NO_HARDWARE_CURSORS" "$CFG" 2>/dev/null || \
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$CFG"
fi

# --- apply now if inside Hyprland ---
APPLIED_NOW=0
if have hyprctl && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  echo "==> Applying now (inside Hyprland)"
  if [[ "$SWWW_MODE" == "swww" ]]; then
    (swww query >/dev/null 2>&1) || swww init || true
    swww img "$WP_IMG" || true
  else
    pkill -x hyprpaper >/dev/null 2>&1 || true
    hyprpaper & disown || true
  fi
  pgrep -x waybar >/dev/null || (waybar & disown)
  pgrep -x mako   >/dev/null || (mako   & disown)
  hyprctl reload -r || true
  APPLIED_NOW=1
fi

echo
echo "============================================"
echo "Done."
echo "• Config backed up to: $CFG.backup.$TS"
echo "• Active wallpaper:    $WP_IMG"
echo "• Wallpaper tool:      $SWWW_MODE"
if [[ "$APPLIED_NOW" -eq 1 ]]; then
  echo "• Changes applied now. Try: Super+Enter (Kitty), Super+Space (Wofi)"
else
  echo "• Log into Hyprland (via SDDM), then it will start automatically."
fi
echo "============================================"