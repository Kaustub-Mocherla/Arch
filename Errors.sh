#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn(){printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\n\033[1;31m[x]\033[0m %s\n' "$*"; exit 1; }

SHELL_DIR="$HOME/.config/quickshell/caelestia"
MOD_DIR="$SHELL_DIR/modules"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/caelestia-shell"

say "Ensuring Caelestia shell folder exists…"
[[ -d "$SHELL_DIR" ]] || die "Shell folder not found at $SHELL_DIR. Run the one-shot installer first."

say "Fetching Caelestia QML modules…"
mkdir -p "$MOD_DIR"
if [[ -d "$MOD_DIR/.git" ]]; then
  (cd "$MOD_DIR" && git pull --rebase --autostash) || warn "git pull on modules had issues; continuing."
else
  # Main modules repo used by Caelestia shell (public)
  git clone --depth=1 https://github.com/caelestia-dots/modules "$MOD_DIR" || die "Clone of modules failed"
fi
ok "Modules present at $MOD_DIR"

# (Optional) some Caelestia setups also carry submodules – initialize if present.
if [[ -f "$MOD_DIR/.gitmodules" ]]; then
  (cd "$MOD_DIR" && git submodule update --init --recursive) || warn "Submodule init failed; continuing."
fi

say "Creating/updating a dedicated runner that sets QML import paths…"
mkdir -p "$BIN_DIR"

cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
# Caelestia runner with QML import paths
CFG="$HOME/.config/quickshell/caelestia"
MOD="$CFG/modules"

# Make sure our per-user bin is in PATH (Hyprland/TTY sessions)
case ":$PATH:" in *":$HOME/.local/bin:"*) : ;; *) export PATH="$HOME/.local/bin:$PATH";; esac

# Qt 6 uses QML2_IMPORT_PATH for QML lookups (additional directories)
# Add Caelestia modules & components folders explicitly:
export QML2_IMPORT_PATH="$MOD:$CFG/components:$QML2_IMPORT_PATH"

# (Some themes use image providers or extra QML dirs named 'qml' or 'libs')
if [[ -d "$CFG/qml" ]]; then
  export QML2_IMPORT_PATH="$CFG/qml:$QML2_IMPORT_PATH"
fi
if [[ -d "$MOD/qml" ]]; then
  export QML2_IMPORT_PATH="$MOD/qml:$QML2_IMPORT_PATH"
fi

# Be conservative on style to avoid missing style plugins
export QT_QUICK_CONTROLS_STYLE=Basic

# Run Caelestia config via QuickShell
exec quickshell -c caelestia "$@"
EOF

chmod +x "$LAUNCHER"
ok "Runner written to $LAUNCHER"

# Patch Hyprland autostart to use our runner (if not already)
HYPR="$HOME/.config/hypr/hyprland.conf"
mkdir -p "$(dirname "$HYPR")"
touch "$HYPR"

if grep -q 'quickshell -c caelestia' "$HYPR"; then
  say "Switching Hyprland exec-once to use the runner (caelestia-shell)…"
  # replace only the exact quickshell line
  sed -i 's~^exec-once *= *quickshell -c caelestia~exec-once = caelestia-shell~' "$HYPR" || true
fi

if ! grep -q 'caelestia-shell' "$HYPR"; then
  printf '\n# Caelestia (with module import paths)\nexec-once = caelestia-shell\n' >> "$HYPR"
fi
ok "Hyprland autostart points to the Caelestia runner."

say "All set."
echo "Now, inside Wayland/Hyprland, run:  caelestia-shell"
echo "If you were in a TTY, start Hyprland first:  Hyprland"