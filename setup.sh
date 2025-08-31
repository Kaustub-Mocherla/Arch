#!/usr/bin/env bash
set -euo pipefail

CE_DIR="$HOME/.config/quickshell/caelestia"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

echo "[i] Making sure base deps are present…"
sudo pacman -Syu --needed --noconfirm \
  git base-devel cmake ninja \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools

# quickshell-git & caelestia-cli should already be there per your logs, but try once more
if ! pacman -Q quickshell-git >/dev/null 2>&1; then
  echo "[!] quickshell-git is missing; install it first (AUR)."
  exit 1
fi
if ! pacman -Q caelestia-cli >/dev/null 2>&1; then
  echo "[!] caelestia-cli is missing; install it first (AUR)."
  exit 1
fi

echo "[i] Ensuring Caelestia shell repo exists at $CE_DIR …"
if [ -d "$CE_DIR/.git" ]; then
  git -C "$CE_DIR" fetch --all --prune
  git -C "$CE_DIR" reset --hard origin/main
else
  rm -rf "$CE_DIR"
  git clone https://github.com/caelestia-dots/shell.git "$CE_DIR"
fi

echo "[i] Building Caelestia shell (CMake + Ninja)…"
cd "$CE_DIR"
rm -rf build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="$CE_DIR"
cmake --build build
sudo cmake --install build
sudo chown -R "$USER:$USER" "$CE_DIR"

echo "[i] Writing launcher…"
cat > "$BIN/caelestia-shell" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="$HOME/.config/quickshell/caelestia"
# Make sure Caelestia modules are on QML path
export QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=wayland
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
EOF
chmod +x "$BIN/caelestia-shell"

echo
echo "[v] Done. Now, inside Hyprland, run:"
echo "    caelestia-shell"
echo
echo "If it still fails with 'module qs.* not installed', run this once to verify:"
echo "    ls -1 $CE_DIR/modules/qs || true"
echo "…you should see: components/  config/  services/  utils/"
echo
echo "You can also launch with an explicit import path for testing:"
echo "    QML2_IMPORT_PATH=$CE_DIR/modules:$QML2_IMPORT_PATH caelestia-shell"