bash -euo pipefail <<'EOF'
LAUNCHER="$HOME/.local/bin/caelestia-shell"
SYS_QML="/usr/lib/qt6/qml"

echo "[*] Patching launcher to also include system QuickShell services…"

cat > "$LAUNCHER" <<LAU
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="\$HOME/.config/quickshell/caelestia"
SYS_QML="$SYS_QML"
export QML2_IMPORT_PATH="\$CE_DIR:\$CE_DIR/modules:\$SYS_QML\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
exec quickshell -c "\$CE_DIR"
LAU

chmod +x "$LAUNCHER"
echo "[+] Done. Now run:  caelestia-shell"
EOF