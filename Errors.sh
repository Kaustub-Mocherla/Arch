bash -euo pipefail <<'EOF'
echo "=== Caelestia: repair install (repos, modules, launcher, checks) ==="

# Paths
HOME_DIR="$HOME"
CE_DIR="$HOME_DIR/.config/quickshell/caelestia"
MOD_DIR="$CE_DIR/modules"
CACHE="$HOME_DIR/.cache/caelestia-src"
LAUNCHER="$HOME_DIR/.local/bin/caelestia-shell"

# 1) Minimal runtime deps (skip if present)
echo "[1/5] Ensuring minimal runtime deps (pacman)…"
sudo pacman -Sy --needed --noconfirm \
  git rsync quickshell-git jq curl unzip \
  swww playerctl pamixer brightnessctl wl-clipboard grim slurp swappy \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools >/dev/null

# 2) Grab BOTH repos (fresh)
echo "[2/5] Syncing Caelestia repos…"
mkdir -p "$CACHE"
if [ -d "$CACHE/caelestia/.git" ]; then
  git -C "$CACHE/caelestia" fetch --all -q || true
  git -C "$CACHE/caelestia" reset --hard origin/main -q || true
else
  git clone https://github.com/caelestia-dots/caelestia "$CACHE/caelestia"
fi
if [ -d "$CACHE/shell/.git" ]; then
  git -C "$CACHE/shell" fetch --all -q || true
  git -C "$CACHE/shell" reset --hard origin/main -q || true
else
  git clone https://github.com/caelestia-dots/shell "$CACHE/shell"
fi

# 3) Install shell.qml + modules from shell repo
echo "[3/5] Installing shell files…"
mkdir -p "$CE_DIR"
install -m 0644 "$CACHE/shell/shell.qml" "$CE_DIR/shell.qml"
rsync -a --delete "$CACHE/shell/modules/" "$MOD_DIR/"

# 3b) Copy main-repo building blocks INTO modules/
# These folders contain qmldir files that declare module names like 'qs.services'
NEEDED=(components services config utils)
for d in "${NEEDED[@]}"; do
  if [ -d "$CACHE/caelestia/$d" ]; then
    rsync -a --delete "$CACHE/caelestia/$d/" "$MOD_DIR/$d/"
    FOUND_QMDIR="$(grep -Rsl '^module[[:space:]]\+qs\.' "$MOD_DIR/$d" || true)"
    if [ -z "$FOUND_QMDIR" ]; then
      echo "  [!] Copied '$d', but did not see a 'module qs.*' qmldir under $MOD_DIR/$d (ok if $d is purely relative includes)."
    else
      echo "  [+] '$d' provides: $(basename "$FOUND_QMDIR")"
    fi
  else
    echo "  [!] Main repo missing folder '$d' — continuing."
  fi
done

# 4) Launcher with correct QML2_IMPORT_PATH (modules + system QML)
echo "[4/5] Writing launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
SYS_QML="/usr/lib/qt6/qml"
# Include Caelestia's top-level dir (for shell.qml’s relative imports)
# and its modules/ (where 'qs.*' qmldirs live), plus system QuickShell QML.
export QML2_IMPORT_PATH="$CE_DIR:$CE_DIR/modules:$SYS_QML${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=wayland
# Use quickshell directly; if 'caelestia' wrapper exists, it will work too.
exec quickshell -c "$CE_DIR"
LAU
chmod +x "$LAUNCHER"

# 5) Sanity checks: confirm qs.services is resolvable
echo "[5/5] Verifying module declarations…"
if grep -Rqs '^module[[:space:]]\+qs\.services' "$MOD_DIR"; then
  echo "  ✓ Detected a qmldir declaring 'qs.services' in $MOD_DIR"
else
  echo "  ✗ Could not find 'module qs.services' under $MOD_DIR"
fi
if grep -Rqs '^module[[:space:]]\+qs\.components' "$MOD_DIR"; then
  echo "  ✓ Detected 'qs.components'"
fi
if grep -Rqs '^module[[:space:]]\+qs\.config' "$MOD_DIR"; then
  echo "  ✓ Detected 'qs.config'"
fi
if grep -Rqs '^module[[:space:]]\+qs\.utils' "$MOD_DIR"; then
  echo "  ✓ Detected 'qs.utils'"
fi

echo
echo "All set. Inside Hyprland, run:  caelestia-shell"
echo "If it still errors, run this and paste the FIRST ~15 lines:"
echo "  QML2_IMPORT_PATH=$CE_DIR:$CE_DIR/modules:/usr/lib/qt6/qml quickshell -c $CE_DIR"
EOF