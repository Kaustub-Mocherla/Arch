bash <<'EOF'
set -euo pipefail

# --- Paths ---
CE_HOME="$HOME/.config/quickshell/caelestia"
CE_DST="$CE_HOME/modules"                 # where Caelestia expects imports
CE_SRC_CACHE="$HOME/.cache/caelestia-src"
CE_SRC="$CE_SRC_CACHE/caelestia"          # main repo local mirror

echo "[1] Ensure folders exist…"
mkdir -p "$CE_DST" "$CE_SRC_CACHE"

echo "[2] Fetch/refresh MAIN repo (caelestia-dots/caelestia)…"
if [ -d "$CE_SRC/.git" ]; then
  git -C "$CE_SRC" pull --ff-only || true
else
  git clone --depth=1 https://github.com/caelestia-dots/caelestia "$CE_SRC"
fi

echo "[3] Copy required Caelestia core modules into QuickShell config…"
need=(config components services utils)
for d in "${need[@]}"; do
  if [ -d "$CE_SRC/$d" ]; then
    echo "   -> syncing $d/"
    rsync -a --delete "$CE_SRC/$d" "$CE_DST"/
  else
    echo "   !! WARNING: '$d' not found in main repo; continuing"
  fi
done

echo "[4] Verify expected directories now exist:"
for d in "${need[@]}"; do
  test -d "$CE_DST/$d" && echo "   ✔ $CE_DST/$d" || echo "   ✖ MISSING: $CE_DST/$d"
done

echo "[5] Make sure launcher exists and exports QML2_IMPORT_PATH…"
mkdir -p "$HOME/.local/bin"
LAUNCHER="$HOME/.local/bin/caelestia-shell"
cat > "$LAUNCHER" <<'LAUNCH'
#!/usr/bin/env bash
set -e
CE_DIR="$HOME/.config/quickshell/caelestia"
export QML2_IMPORT_PATH="$CE_DIR/modules:${QML2_IMPORT_PATH:+$QML2_IMPORT_PATH}"
exec quickshell -c "$CE_DIR/shell.qml"
LAUNCH
chmod +x "$LAUNCHER"

# Add to PATH for this session in case it's not picked up yet
case ":$PATH:" in *":$HOME/.local/bin:"*) :;; *) export PATH="$HOME/.local/bin:$PATH";; esac

echo
echo "✅ Done."
echo "Try now (inside Hyprland):"
echo "  caelestia-shell"
echo
echo "If you still see import warnings, show the output of:"
echo "  ls -1 $CE_DST ; echo ; ls -1 $CE_DST/components ; ls -1 $CE_DST/services"
EOF