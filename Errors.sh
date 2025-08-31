bash -c '
set -euo pipefail

echo "[1/5] Install fonts from official repos (safe to re-run)…"
sudo pacman -Syu --needed --noconfirm \
  ttf-cascadia-code-nerd noto-fonts noto-fonts-cjk ttf-liberation

echo "[2/5] Install Material Symbols Rounded locally…"
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Download the variable Material Symbols Rounded TTF from Google s repo.
# If curl fails (network/mirror issues), it won’t break existing files.
MSR_TTF="$FONT_DIR/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
if [ ! -f "$MSR_TTF" ]; then
  echo "    - Downloading Material Symbols Rounded (variable TTF)…"
  curl -L --retry 3 --retry-connrefused --fail \
    -o "$MSR_TTF" \
    https://raw.githubusercontent.com/google/material-design-icons/master/font/variable/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf
else
  echo "    - Already present: $MSR_TTF"
fi

echo "[3/5] Rebuild font cache…"
fc-cache -f

echo "[4/5] Show fonts we just installed (for sanity)…"
fc-list | grep -Ei "MaterialSymbolsRounded|Cascadia|Caskaydia" || true

echo "[5/5] Launch Caelestia…"
# Use the launcher that exports QML2_IMPORT_PATH for modules:
if command -v caelestia-shell >/dev/null 2>&1; then
  caelestia-shell
else
  echo "caelestia-shell launcher not found in PATH. Try: source ~/.profile && caelestia-shell"
fi
'