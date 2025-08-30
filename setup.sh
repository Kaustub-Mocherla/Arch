mkdir -p ~/.local/bin ~/.config/quickshell/caelestia
cat > ~/.local/bin/caelestia-shell <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONF="$HOME/.config/quickshell/caelestia/shell.qml"
MODS="$HOME/.config/quickshell/caelestia/modules"

# Quick sanity checks
if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
  echo "[x] Not in a Wayland session (XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}). Start this from Hyprland." >&2
  exit 1
fi
if ! command -v quickshell >/dev/null 2>&1; then
  echo "[x] 'quickshell' is not installed or not in PATH." >&2
  exit 1
fi
if [[ ! -f "$CONF" ]]; then
  echo "[x] Missing config: $CONF" >&2
  exit 1
fi
if [[ ! -d "$MODS" ]]; then
  echo "[x] Missing modules dir: $MODS" >&2
  exit 1
fi

# Force Wayland Qt and make sure QML can find the modules
export QT_QPA_PLATFORM=wayland
export QML2_IMPORT_PATH="$MODS${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

# Optional: quiet QuickShell’s “xcb” probing noise
export QT_QPA_PLATFORMTHEME=qt6ct

exec quickshell -c "$CONF"
EOF
chmod +x ~/.local/bin/caelestia-shell
hash -r