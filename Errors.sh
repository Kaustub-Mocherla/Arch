cat > ~/fix_caelestia.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"

# quick sanity check
if [ ! -d "$CE_DIR/modules" ] || [ ! -f "$CE_DIR/shell.qml" ]; then
  echo "[x] Expected Caelestia files missing in $CE_DIR"
  ls -la "$CE_DIR" || true
  exit 2
fi

# Make/overwrite the launcher
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
# Make sure Caelestia QML modules are found
export QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
# IMPORTANT: QuickShell 0.2 expects the DIRECTORY, not shell.qml
exec quickshell -c "$CE_DIR"
LAUNCH
chmod +x "$HOME/.local/bin/caelestia-shell"

# Ensure ~/.local/bin is on PATH for this and future shells
PROFILE="$HOME/.profile"
if ! grep -q '\.local/bin' "$PROFILE" 2>/dev/null; then
  printf '\n# Add ~/.local/bin to PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$PROFILE"
fi
# Load PATH now (ignore errors if any)
. "$PROFILE" 2>/dev/null || true

echo "[✓] Launcher installed at ~/.local/bin/caelestia-shell"
echo "[i] Quick check:"
type -a caelestia-shell || true
ls -l "$CE_DIR" || true

# If we're already inside Wayland (Hyprland), start it now
if [ -n "${WAYLAND_DISPLAY-}" ]; then
  echo "[→] Launching Caelestia…"
  exec env QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}" \
       quickshell -c "$CE_DIR"
else
  echo "[!] Not in a Wayland session. Open Hyprland and run:  caelestia-shell"
fi
EOF

bash ~/fix_caelestia.sh