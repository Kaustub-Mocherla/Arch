bash -euo pipefail <<'EOF'
# --- constants ---------------------------------------------------------------
CE_DIR="$HOME/.config/quickshell/caelestia"
CACHE="$HOME/.cache/caelestia-src/caelestia"
REPO="https://github.com/caelestia-dots/caelestia.git"
LAUNCHER="$HOME/.local/bin/caelestia-shell"

echo "[1/4] Ensure folders exist…"
mkdir -p "$CE_DIR" "$CE_DIR/modules" "$(dirname "$CACHE")"

echo "[2/4] Fetch/refresh MAIN repo (components/services/config/utils)…"
if [ -d "$CACHE/.git" ]; then
  git -C "$CACHE" fetch --all -q || true
  git -C "$CACHE" reset --hard origin/HEAD -q || true
else
  git clone --depth=1 "$REPO" "$CACHE"
fi

# What we need from the main repo:
NEEDED=(components services config utils)
MISSING=0
for d in "${NEEDED[@]}"; do
  if [ -d "$CACHE/$d" ]; then
    echo "  - copying $d/"
    rsync -a --delete "$CACHE/$d/" "$CE_DIR/$d/"
  else
    echo "  !! WARNING: '$d' not found in main repo"
    MISSING=1
  fi
done

echo "[3/4] Patch launcher to expose these modules to QML…"
cat > "$LAUNCHER" <<LAU
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="\$HOME/.config/quickshell/caelestia"
SYS_QML="/usr/lib/qt6/qml"
# Add Caelestia dirs + system QuickShell QML to the search path
export QML2_IMPORT_PATH="\$CE_DIR:\$CE_DIR/modules:\$CE_DIR/services:\$CE_DIR/components:\$SYS_QML\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
exec quickshell -c "\$CE_DIR"
LAU
chmod +x "$LAUNCHER"

echo "[4/4] Verify that 'qs.services' is now discoverable…"
# A quick sanity check: the Caelestia repo ships a qmldir like: 'module qs.services'
if grep -Rqs '^module[[:space:]]\+qs\.services' "$CE_DIR/services" 2>/dev/null; then
  echo "  ✓ Found 'qs.services' qmldir under \$CE_DIR/services"
else
  echo "  ✗ Could not find a qmldir declaring 'qs.services' under \$CE_DIR/services"
  echo "    (If the main repo changed layout, we’ll need to adjust paths.)"
fi

echo
if [ "$MISSING" -eq 1 ]; then
  echo "Done with warnings. Try launching anyway:"
else
  echo "All set."
fi
echo "Run inside Hyprland:  caelestia-shell"
EOF