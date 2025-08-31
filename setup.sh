#!/usr/bin/env bash
set -euo pipefail

echo "[i] Installing repo fonts (safe)…"
sudo pacman -Syu --needed --noconfirm \
  noto-fonts noto-fonts-cjk noto-fonts-emoji \
  ttf-dejavu ttf-liberation \
  ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
  echo "[i] Trying to install Material Symbols via $AUR_HELPER (best effort)…"
  # Try several common package names; ignore failures.
  $AUR_HELPER -S --needed --noconfirm \
    ttf-material-symbols || true
  $AUR_HELPER -S --needed --noconfirm \
    material-symbols || true
  $AUR_HELPER -S --needed --noconfirm \
    ttf-material-symbols-rounded || true
  $AUR_HELPER -S --needed --noconfirm \
    ttf-material-icons || true
else
  echo "[!] No AUR helper found (paru/yay)."
  echo "    You can install one later to get Material Symbols specifically."
  echo "    For now, Nerd Symbols + Noto will install and most UI text renders correctly."
fi

echo "[i] Rebuilding font cache…"
fc-cache -f

# Small pause so cache settles on slower disks
sleep 1

# Re-launch Caelestia with explicit import path just in case
CE_DIR="$HOME/.config/quickshell/caelestia"
export QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=wayland

echo
echo "[v] Fonts refreshed. Launching Caelestia…"
if command -v caelestia >/dev/null 2>&1; then
  caelestia shell -d || true
else
  quickshell -c "$CE_DIR" || true
fi

echo
echo "[Tip] If icons still show as words, it means Material Symbols didn’t install yet."
echo "      Once you have an AUR helper, run one of:"
echo "        paru  -S ttf-material-symbols"
echo "        yay   -S ttf-material-symbols"