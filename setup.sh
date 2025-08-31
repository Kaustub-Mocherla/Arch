cat > ~/fix_qml_path.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
QS_QML="/usr/share/quickshell/modules"

if [ ! -d "$CE_DIR" ]; then
  echo "[x] Caelestia not found in $CE_DIR"
  exit 1
fi

if [ ! -d "$QS_QML" ]; then
  echo "[!] QuickShell QML modules not found in $QS_QML"
  echo "    Run:  pacman -Ql quickshell | grep modules"
  exit 2
fi

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<LAUNCH
#!/usr/bin/env bash
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
QS_QML="$QS_QML"
export QML2_IMPORT_PATH="\$CE_DIR/modules:\$QS_QML\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
exec quickshell -c "\$CE_DIR"
LAUNCH
chmod +x "$HOME/.local/bin/caelestia-shell"

echo "[✓] Updated caelestia-shell launcher to include QuickShell modules."
echo "    Try running now: caelestia-shell"
EOF

bash ~/fix_qml_path.sh Try running: quickshell --version"