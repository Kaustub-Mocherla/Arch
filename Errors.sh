bash -euo pipefail <<'EOF'
CE="$HOME/.config/quickshell/caelestia"
MOD="$CE/modules"

echo "[1/4] Ensure Caelestia directory exists…"
[ -d "$CE" ] || { echo "Caelestia not installed at $CE"; exit 1; }

echo "[2/4] Move core dirs out of modules/ to the top-level (as Caelestia expects)…"
for d in components services config utils; do
  if [ -d "$MOD/$d" ]; then
    mkdir -p "$CE/$d"
    rsync -a --delete "$MOD/$d/" "$CE/$d/"
    rm -rf "$MOD/$d"
    echo "  • fixed: $d -> $CE/$d"
  fi
done

echo "[3/4] Recreate launcher with both import paths (root + modules)…"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
# Make both the root and modules visible to QML:
export QML2_IMPORT_PATH="$CE_DIR:$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
exec quickshell -c "$CE_DIR"
LAU
chmod +x "$HOME/.local/bin/caelestia-shell"

echo "[4/4] Quick sanity check…"
ls -1 "$CE" | sed 's/^/  - /'
echo
echo "Done. Inside Hyprland, run:  caelestia-shell"
echo "If wallpaper still says missing, make sure swww is running, then do:"
echo "  swww init 2>/dev/null || true && swww img ~/Pictures/anything.jpg || true"
EOF