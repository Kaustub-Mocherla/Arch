#!/usr/bin/env bash
set -euo pipefail

echo "== Caelestia Shell — repair (clone, build, install to ~/.config) =="

# Paths
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
SRC_DIR="$HOME/.cache/caelestia-shell-src"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/caelestia-shell"

mkdir -p "$BIN_DIR" "$SRC_DIR"

# 0) Quick preflight
echo "[0] Checking QuickShell + CLI presence…"
if ! command -v quickshell >/dev/null 2>&1; then
  echo "!! quickshell is not on PATH. Install quickshell-git first, then re-run."
  exit 1
fi
if ! command -v caelestia >/dev/null 2>&1; then
  echo "!! caelestia CLI is not on PATH. Install caelestia-cli (AUR), then re-run."
  exit 1
fi

# 1) Minimal repo deps (all repo packages; no AUR pulls here)
echo "[1] Installing minimal runtime libs from repos…"
sudo pacman -Sy --needed --noconfirm \
  cmake ninja git \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  curl unzip jq \
  wl-clipboard grim slurp swappy \
  playerctl pamixer brightnessctl \
  noto-fonts ttf-liberation ttf-cascadia-code-nerd || true

# 2) Clone/refresh ONLY the shell repo (not the main dots)
echo "[2] Syncing caelestia-dots/shell…"
if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" remote set-url origin https://github.com/caelestia-dots/shell.git || true
  git -C "$SRC_DIR" fetch --all --prune
  git -C "$SRC_DIR" reset --hard origin/main
else
  rm -rf "$SRC_DIR"
  git clone https://github.com/caelestia-dots/shell.git "$SRC_DIR"
fi

# 3) Build and install into ~/.config/quickshell/caelestia (per README)
echo "[3] Building + installing into $CE_DIR …"
mkdir -p "$CE_DIR"
pushd "$SRC_DIR" >/dev/null
rm -rf build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$CE_DIR"
cmake --build build
sudo cmake --install build
sudo chown -R "$USER:$USER" "$CE_DIR"
popd >/dev/null

# 4) Ensure the shell’s own modules (components/services/config/utils) are present
echo "[4] Verifying Caelestia shell modules…"
need=(components services config utils)
missing=0
for d in "${need[@]}"; do
  if [ ! -d "$CE_DIR/$d" ] && [ ! -d "$CE_DIR/modules/$d" ]; then
    echo "!! Missing: $d"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "!! Some Caelestia shell folders are missing. This should not happen."
  echo "   Tree of $CE_DIR:"
  find "$CE_DIR" -maxdepth 2 -type d -printf "   %p\n" || true
fi

# 5) Launcher — export QML2_IMPORT_PATH to include Caelestia + system QML dir
echo "[5] Writing launcher to $LAUNCHER …"
cat > "$LAUNCHER" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"

# Include Caelestia’s QML dirs and system QuickShell QML dir
SYS_QML="/usr/lib/qt6/qml"
export QML2_IMPORT_PATH="$CE_DIR/modules:$CE_DIR:$SYS_QML${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

# Prefer Wayland
export QT_QPA_PLATFORM=wayland

# Run via CLI if present (for IPC features), else run plain quickshell
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
LAU
chmod +x "$LAUNCHER"

# 6) Light sanity checks
echo "[6] Quick checks…"
echo "   • shell.qml  -> $([ -f "$CE_DIR/shell.qml" ] && echo OK || echo MISSING)"
echo "   • modules/   -> $([ -d "$CE_DIR/modules" ] && echo OK || echo MISSING)"
echo "   • components -> $([ -d "$CE_DIR/components" ] && echo OK || echo MISSING)"
echo "   • services   -> $([ -d "$CE_DIR/services" ] && echo OK || echo MISSING)"
echo "   • config     -> $([ -d "$CE_DIR/config" ] && echo OK || echo MISSING)"
echo "   • utils      -> $([ -d "$CE_DIR/utils" ] && echo OK || echo MISSING)"

echo
echo "✓ Done. Launch inside Hyprland with:  caelestia-shell"
echo "  If you still see 'Type Background unavailable' or 'qs.services not installed',"
echo "  run:   quickshell -c \"$CE_DIR\"   and paste the first 20 lines of output."