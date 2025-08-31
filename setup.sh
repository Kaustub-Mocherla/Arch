#!/bin/bash
set -e

CE_DIR="$HOME/.config/quickshell/caelestia"
QS_DIR="/usr/lib/qt6/qml"

if [ ! -f "$CE_DIR/shell.qml" ]; then
    echo "[x] ERROR: shell.qml not found in $CE_DIR"
    exit 1
fi

echo "[i] Writing fixed launcher..."

cat > "$HOME/.local/bin/caelestia-shell" <<EOF
#!/bin/bash
export QML2_IMPORT_PATH="$CE_DIR/modules:$QS_DIR\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
exec quickshell -c "$CE_DIR"
EOF

chmod +x "$HOME/.local/bin/caelestia-shell"

echo "[✓] Launcher fixed."
echo "Now run:  caelestia-shell   (inside Hyprland session)"