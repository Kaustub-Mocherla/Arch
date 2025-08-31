mkdir -p ~/.local/bin

cat > ~/.local/bin/caelestia-shell <<'EOF'
#!/usr/bin/env bash
CFG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
CE_DIR="$CFG_ROOT/quickshell/caelestia"
export QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
exec quickshell -c "$CE_DIR/shell.qml"
EOF

chmod +x ~/.local/bin/caelestia-shell