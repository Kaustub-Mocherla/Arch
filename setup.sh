#!/usr/bin/env bash
set -Eeuo pipefail

LOG="$HOME/caelestia_fix.log"
exec > >(tee -a "$LOG") 2>&1

say() { printf "\033[1;36m[i]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[v]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# 0) quick sanity
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

say "Starting Caelestia full reset + install. Log: $LOG"

# 1) pacman deps
say "Installing base dependencies (pacman)…"
sudo pacman -Sy --needed --noconfirm \
  base-devel git curl unzip tar cmake ninja \
  qt6-base qt6-declarative qt6-svg qt6-wayland \
  glibc gcc-libs \
  hyprland kitty wl-clipboard pipewire wireplumber \
  swappy brightnessctl ddcutil lm_sensors libqalculate cava || {
    err "pacman failed (check mirrors/network)."; exit 1; }
ok "Base deps installed."

# 2) AUR helper (yay)
if ! need_cmd yay; then
  say "Installing AUR helper (yay)…"
  workdir="$(mktemp -d)"
  pushd "$workdir" >/dev/null
  git clone --depth=1 https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf "$workdir"
  ok "yay installed."
else
  ok "yay already present."
fi

# 3) AUR packages: quickshell (git) + caelestia-cli
say "Installing AUR packages (quickshell-git, caelestia-cli)…"
yay -S --needed --noconfirm quickshell-git caelestia-cli || {
  err "Failed installing AUR packages."; exit 1; }
ok "AUR packages installed."

# 4) Clean old local installs/config (keep Hyprland config)
say "Cleaning previous local Caelestia/QuickShell config (safe)…"
rm -rf "$XDG_CONFIG_HOME/quickshell/caelestia" || true
# keep hyprland conf; only ensure exec-once is (re-)added later.
ok "Old Caelestia config removed."

# 5) Clone + build Caelestia shell (local user install)
SRC_DIR="$HOME/.cache/caelestia-src"
INSTALL_QML="$HOME/.local/share/qt6/qml"
INSTALL_LIB="$HOME/.local/lib"
INSTALL_QSCONF="$XDG_CONFIG_HOME/quickshell/caelestia"

mkdir -p "$SRC_DIR" "$INSTALL_QML" "$INSTALL_LIB" "$INSTALL_QSCONF" "$HOME/.local/bin"

say "Cloning caelestia-dots/shell…"
rm -rf "$SRC_DIR/shell"
git clone --depth=1 https://github.com/caelestia-dots/shell.git "$SRC_DIR/shell" || {
  err "Clone failed."; exit 1; }
ok "Repo cloned."

say "Building Caelestia shell (CMake + Ninja)…"
pushd "$SRC_DIR/shell" >/dev/null
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QMLDIR="$INSTALL_QML" \
  -DINSTALL_LIBDIR="$INSTALL_LIB" \
  -DINSTALL_QSCONFDIR="$INSTALL_QSCONF"

cmake --build build
cmake --install build  # installs into $HOME paths above because we set dirs
popd >/dev/null
ok "Caelestia shell built and installed to user prefix."

# 6) Launcher script
LAUNCHER="$HOME/.local/bin/caelestia-shell"
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Ensure user-local QML + libs are visible
export QML2_IMPORT_PATH="$HOME/.local/share/qt6/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
# Prefer the CLI launcher if available (enables IPC etc.), else fall back to qs
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec qs -c caelestia
fi
EOF
chmod +x "$LAUNCHER"
ok "Launcher created: $LAUNCHER"

# 7) Ensure ~/.local/bin is on PATH for interactive shells
PROFILE_FILE="$HOME/.profile"
if ! grep -qs 'PATH=.*\.local/bin' "$PROFILE_FILE"; then
  say "Adding ~/.local/bin to PATH in $PROFILE_FILE…"
  {
    echo ''
    echo '# Added by Caelestia installer'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$PROFILE_FILE"
fi
ok "~/.local/bin will be in PATH next login (source ~/.profile to load now)."

# 8) Add Hyprland autostart (idempotent)
HYPRCONF="$XDG_CONFIG_HOME/hypr/hyprland.conf"
mkdir -p "$(dirname "$HYPRCONF")"
if [[ -f "$HYPRCONF" ]]; then
  if ! grep -qs 'exec-once *=.*caelestia-shell' "$HYPRCONF"; then
    say "Adding Caelestia autostart to Hyprland config…"
    printf '\n# Caelestia autostart\nexec-once = %s\n' "$LAUNCHER" >> "$HYPRCONF"
  else
    ok "Hyprland autostart already present."
  fi
else
  say "Creating Hyprland config with Caelestia autostart…"
  cat > "$HYPRCONF" <<EOF
# Minimal Hyprland config
monitor=,preferred,auto,1
exec-once = $LAUNCHER
EOF
fi
ok "Hyprland configured."

# 9) QuickShell headless check (we can't truly run Wayland here)
say "Verifying QuickShell binary…"
if ! command -v qs >/dev/null 2>&1; then
  err "qs (quickshell) not found in PATH. Check quickshell-git installation."
  exit 1
fi
ok "qs present."

# 10) Final tips
ok "All set."
cat <<'TIP'

To start Caelestia shell:

  1) Log into a Wayland session with Hyprland (your greeter will have Hyprland).
  2) It should autostart. If you see only the Hyprland splash triangles,
     press Super+Enter (opens kitty), then run:
         caelestia-shell

Useful:

  - Logs:  ~/caelestia_fix.log
  - Config: ~/.config/quickshell/caelestia
  - If fonts look off, install:
        yay -S ttf-caskaydia-cove-nerd ttf-material-symbols

If you *still* see “module 'Caelestia' is not installed”, run this in a terminal
(after logging into Hyprland), to ensure QML path is visible:

    export QML2_IMPORT_PATH="$HOME/.local/share/qt6/qml:$QML2_IMPORT_PATH"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
    caelestia-shell

TIP