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
rsync -a --delete "$CACHE/shell/themes/" "$CFG/themes/"
rsync -a --delete "$CACHE/shell/config/" "$CFG/config/"

echo "[3/4] Verify structure…"
ls -1 "$CFG"
ls -1 "$CFG/modules" | head
ls -1 "$CFG/themes" | head

echo "[4/4] Done. Launch with:"
echo "   caelestia-shell"
echo
echo "Now you should see themes + modules."