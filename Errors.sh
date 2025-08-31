bash -euo pipefail <<'EOF'
# Material Symbols Rounded (variable TTF) — lightweight install

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
TMP="$(mktemp -d)"
TTF_NAME="MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
TTF_URL="https://github.com/google/material-design-icons/blob/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf?raw=1"

echo "[1/4] Ensuring font dir: $FONT_DIR"
mkdir -p "$FONT_DIR"

echo "[2/4] Downloading $TTF_NAME (few MB)…"
curl -fL --retry 3 --retry-delay 2 -o "$TMP/$TTF_NAME" "$TTF_URL"

# quick sanity check: file should be > 1MB
SZ=$(stat -c%s "$TMP/$TTF_NAME" 2>/dev/null || echo 0)
if [ "$SZ" -lt 1000000 ]; then
  echo "Download looks too small ($SZ bytes). Aborting to be safe." >&2
  exit 1
fi

echo "[3/4] Installing font into $FONT_DIR"
install -m 0644 "$TMP/$TTF_NAME" "$FONT_DIR/"

echo "[4/4] Refreshing font cache"
fc-cache -f "$FONT_DIR" >/dev/null || true

echo "✓ Material Symbols Rounded installed."
echo "If Caelestia is running, reload it or log out/in to pick up the font."
rm -rf "$TMP"
EOF