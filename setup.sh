#!/bin/bash
set -e

CE_SRC="$HOME/.cache/caelestia-src/caelestia"
CE_DST="$HOME/.config/quickshell/caelestia/modules"

echo "[1] Checking source repo: $CE_SRC"
ls -1 "$CE_SRC" || { echo "!! Main repo not found"; exit 1; }

echo "[2] Creating destination if missing: $CE_DST"
mkdir -p "$CE_DST"

echo "[3] Copying missing folders (config, components, services, utils)..."
for d in config components services utils; do
  if [ -d "$CE_SRC/$d" ]; then
    echo "   -> syncing $d"
    rsync -av --delete "$CE_SRC/$d" "$CE_DST/"
  else
    echo "   -> WARNING: $d not found in source repo"
  fi
done

echo "[4] Verifying..."
ls -1 "$CE_DST"

echo
echo "✅ Done. Now try inside Hyprland:"
echo "   caelestia-shell"