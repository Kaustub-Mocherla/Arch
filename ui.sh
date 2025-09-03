#!/usr/bin/env bash
set -euo pipefail

CFG="$HOME/.config/quickshell/caelestia"
CACHE="$HOME/.cache/caelestia-src"

echo "[1/4] Clone or update caelestia-shell repo…"
if [ -d "$CACHE/shell/.git" ]; then
  git -C "$CACHE/shell" pull --ff-only
else
  mkdir -p "$CACHE"
  git clone https://github.com/caelestia-dots/shell "$CACHE/shell"
fi

echo "[2/4] Install shell files…"
mkdir -p "$CFG"
rsync -a --delete "$CACHE/shell/shell.qml" "$CFG/"
rsync -a --delete "$CACHE/shell/modules/" "$CFG/modules/"

# only copy if folder exists
for d in themes config; do
  if [ -d "$CACHE/shell/$d" ]; then
    rsync -a --delete "$CACHE/shell/$d/" "$CFG/$d/"
    echo "✓ Copied $d/"
  else
    echo "!! Skipping $d/ (not present in repo)"
  fi
done

echo "[3/4] Verify structure…"
ls -1 "$CFG"

echo "[4/4] Done. Launch with:"
echo "   caelestia-shell"