bash -c '
set -euo pipefail

echo "[1/4] Install core fonts from Arch repos…"
sudo pacman -Syu --needed --noconfirm \
  ttf-cascadia-code-nerd noto-fonts noto-fonts-cjk ttf-liberation unzip curl

echo "[2/4] Download Material Symbols (latest official release)…"
TMPDIR="$(mktemp -d)"
curl -L --retry 3 --retry-connrefused --fail \
  -o "$TMPDIR/material-symbols.zip" \
  https://github.com/google/material-design-icons/archive/refs/heads/master.zip

echo "[3/4] Extract Rounded fonts…"
unzip -q "$TMPDIR/material-symbols.zip" -d "$TMPDIR"
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# copy Rounded TTFs if available
find "$TMPDIR" -type f -iname "MaterialSymbolsRounded*.ttf" -exec cp {} "$FONT_DIR/" \;

echo "[4/4] Refresh font cache…"
fc-cache -f
fc-list | grep -Ei "Material|Caskaydia|Cascadia" || true

echo "✅ Fonts installed. Try restarting Hyprland and running:  caelestia-shell"
'