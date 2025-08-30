#!/usr/bin/env bash
# Caelestia (QuickShell) one-shot installer for Arch/Hyprland
set -euo pipefail

LOG="$HOME/caelestia_one_shot.log"
: > "$LOG"  # truncate

say()  { printf "\033[1;36m[i]\033[0m %s\n" "$*" | tee -a "$LOG"; }
ok()   { printf "\033[1;32m[v]\033[0m %s\n" "$*" | tee -a "$LOG"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" | tee -a "$LOG"; }
die()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" | tee -a "$LOG"; exit 1; }

# --- preflight ---------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  die "Run as your normal user, not root."
fi

if ! ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
  warn "Network check failed (archlinux.org didn’t reply). Continuing anyway…"
fi

# --- package helpers ---------------------------------------------------------
need_pkgs=(git curl unzip tar qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools qt6-quickcontrols2 hyprland kitty pipewire wireplumber wl-clipboard)
say "Installing/updating required packages (pacman)…"
if ! sudo pacman -Sy --needed --noconfirm "${need_pkgs[@]}" 2>&1 | tee -a "$LOG"; then
  die "pacman failed. Check mirrors/network."
fi
ok "Base packages present."

# Ensure yay (AUR helper) if we need it later
ensure_yay() {
  if command -v yay >/dev/null 2>&1; then return; fi
  say "Installing yay (AUR helper)…"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay" >>"$LOG" 2>&1
  pushd "$tmp/yay" >/dev/null
  makepkg -si --noconfirm >>"$LOG" 2>&1 || die "Failed to build yay."
  popd >/dev/null
  ok "yay installed."
}

# --- QuickShell --------------------------------------------------------------
install_quickshell() {
  if command -v quickshell >/dev/null 2>&1; then
    ok "QuickShell already present."
    return
  fi
  say "Installing QuickShell (pacman)…"
  if sudo pacman -S --noconfirm --needed quickshell >>"$LOG" 2>&1; then
    ok "QuickShell installed via pacman."
    return
  fi
  warn "pacman: quickshell not found. Falling back to AUR."
  ensure_yay
  if yay -S --noconfirm quickshell-git >>"$LOG" 2>&1 || yay -S --noconfirm quickshell-bin >>"$LOG" 2>&1; then
    ok "QuickShell installed via AUR."
  else
    die "Failed to install QuickShell."
  fi
}
install_quickshell

# --- paths -------------------------------------------------------------------
QS_CFG_DIR="$HOME/.config/quickshell/caelestia"
QS_QML_ROOT="$QS_CFG_DIR/qml"                 # parent of the Caelestia module dir
CAE_MODULE_DIR="$QS_QML_ROOT/Caelestia"       # module directory (must be named Caelestia)
LAUNCHER_DIR="$HOME/.local/bin"
LAUNCHER_BIN="$LAUNCHER_DIR/caelestia-shell"

mkdir -p "$QS_CFG_DIR" "$CAE_MODULE_DIR" "$LAUNCHER_DIR"

# --- fetch repos -------------------------------------------------------------
SRC_ROOT="$HOME/.cache/caelestia-src"
CAEL_MAIN="$SRC_ROOT/caelestia"
CAEL_SHELL="$SRC_ROOT/shell"

say "Cloning Caelestia main repo (full)…"
rm -rf "$CAEL_MAIN"
git clone https://github.com/caelestia-dots/caelestia.git "$CAEL_MAIN" >>"$LOG" 2>&1 || die "Clone failed (main)."
ok "Main repo cloned."

say "Cloning Caelestia shell repo (full)…"
rm -rf "$CAEL_SHELL"
git clone https://github.com/caelestia-dots/shell.git "$CAEL_SHELL" >>"$LOG" 2>&1 || die "Clone failed (shell)."
ok "Shell repo cloned."

# --- place shell files -------------------------------------------------------
# We expect a top-level shell.qml inside the shell repo (or under a directory)
shell_src=""
if [[ -f "$CAEL_SHELL/shell.qml" ]]; then
  shell_src="$CAEL_SHELL"
else
  # try to find it
  found="$(grep -RIl --max-count=1 '^import ' "$CAEL_SHELL" | grep '/shell.qml$' || true)"
  if [[ -n "$found" ]]; then shell_src="$(dirname "$found")"; fi
fi
[[ -n "$shell_src" ]] || die "shell.qml not found inside shell repo."

say "Installing shell config to $QS_CFG_DIR…"
rsync -a --delete "$shell_src/." "$QS_CFG_DIR/." >>"$LOG" 2>&1
ok "Shell config copied."

# --- modules (QML) -----------------------------------------------------------
# The QML modules can live in either repo. Prefer 'shell/modules', fallback to 'caelestia/modules'.
modules_src=""
for path in "$CAEL_SHELL/modules" "$CAEL_MAIN/modules"; do
  if [[ -d "$path" ]] && compgen -G "$path/*" >/dev/null; then
    modules_src="$path"
    break
  fi
done
[[ -n "$modules_src" ]] || die "No 'modules/' directory found in either repo."

say "Placing QML modules as module 'Caelestia'…"
# Put the *contents* of modules/ into Caelestia/ (so the module name is 'Caelestia')
rsync -a --delete "$modules_src/" "$CAE_MODULE_DIR/" >>"$LOG" 2>&1

# Ensure a qmldir that declares the module name (if missing)
if ! grep -q '^module Caelestia' "$CAE_MODULE_DIR/qmldir" 2>/dev/null; then
  say "Creating qmldir for Caelestia module…"
  {
    echo "module Caelestia"
    echo "prefer :/  # allow relative imports"
  } > "$CAE_MODULE_DIR/qmldir"
fi
ok "QML module ready at $CAE_MODULE_DIR"

# --- launcher ---------------------------------------------------------------
say "Creating launcher $LAUNCHER_BIN …"
cat > "$LAUNCHER_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="$HOME/.config/quickshell/caelestia/shell.qml"
QML_CAEL="$HOME/.config/quickshell/caelestia/qml"
export QML2_IMPORT_PATH="$QML_CAEL${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
exec quickshell -c "$CFG"
EOF
chmod +x "$LAUNCHER_BIN"
ok "Launcher installed."

# Ensure ~/.local/bin in PATH at next login
if ! grep -qs '\.local/bin' "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zprofile" 2>/dev/null; then
  say "Adding ~/.local/bin to PATH in ~/.profile …"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

# --- Hyprland autostart -----------------------------------------------------
HYPR_DIR="$HOME/.config/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"
mkdir -p "$HYPR_DIR"
if [[ -f "$HYPR_CONF" ]]; then
  if ! grep -q 'exec-once *= *caelestia-shell' "$HYPR_CONF"; then
    say "Adding autostart to Hyprland config…"
    printf "\n# Caelestia\nexec-once = caelestia-shell\n" >> "$HYPR_CONF"
  else
    ok "Hyprland autostart already present."
  fi
else
  say "Creating basic Hyprland config with Caelestia autostart…"
  cat > "$HYPR_CONF" <<'EOF'
# Minimal Hyprland config
monitor=,preferred,auto,auto
exec-once = caelestia-shell
EOF
fi

# --- run now if we are inside Wayland ---------------------------------------
if [[ "${XDG_SESSION_TYPE:-}" = "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  say "Wayland session detected; starting Caelestia now…"
  if pgrep -x quickshell >/dev/null 2>&1; then
    warn "An existing QuickShell instance is running. Not launching another."
  else
    ( "$LAUNCHER_BIN" >>"$LOG" 2>&1 & disown ) || warn "Launch failed; see $LOG"
  fi
else
  warn "You’re not in Wayland now (probably on a TTY)."
  say  "After you log into Hyprland, it will autostart. You can also run: caelestia-shell"
fi

ok "All set. Log: $LOG"