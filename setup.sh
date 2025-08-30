#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Caelestia (QuickShell) one-shot installer/repair for Arch/Hyprland
# - Installs deps (via pacman + yay if needed)
# - Clones caelestia-dots/caelestia (main) and caelestia-dots/shell (UI)
# - Copies shell.qml + modules/ into ~/.config/quickshell/caelestia
# - Creates launcher ~/.local/bin/caelestia-shell that exports QML2_IMPORT_PATH
# - Adds Hyprland exec-once = caelestia-shell (idempotent)
# --------------------------

ME="$(basename "$0")"
USER_NAME="$(id -un)"
HOME_DIR="$HOME"
LOG="/var/log/caelestia_one_shot.log"

say()   { printf "\033[1;36m[+] %s\033[0m\n" "$*"; }
ok()    { printf "\033[1;32m[v] %s\033[0m\n" "$*"; }
warn()  { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
die()   { printf "\033[1;31m[x] %s\033[0m\n" "$*"; exit 1; }

# We’ll write a short tail of the log at the end if something fails
sudo sh -c "touch '$LOG' && chown $USER_NAME:$USER_NAME '$LOG'" || true

# --------------------------
# Basic checks
# --------------------------
[[ "$EUID" -eq 0 ]] && die "Run as your normal user, not root."
command -v sudo >/dev/null 2>&1 || die "sudo not found."

# Quick network check (non-fatal)
if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
  ok "Network looks OK."
else
  warn "Network check failed (ping archlinux.org). Continuing anyway."
fi

# --------------------------
# Ensure yay (for AUR)
# --------------------------
ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already present."
    return
  fi
  say "Installing yay (AUR helper)…"
  sudo pacman -Sy --noconfirm --needed git base-devel || die "pacman failed."
  builddir="$HOME_DIR/.cache/yaybuild"
  rm -rf "$builddir"
  mkdir -p "$builddir"
  pushd "$builddir" >/dev/null
    git clone https://aur.archlinux.org/yay.git .
    makepkg -si --noconfirm
  popd >/dev/null
  ok "yay installed."
}

# --------------------------
# Packages
# --------------------------
install_packages() {
  say "Installing/updating required packages… (pacman)"
  sudo pacman -Sy --noconfirm --needed \
    git curl unzip tar \
    qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
    pipewire wireplumber wl-clipboard kitty hyprland \
    xdg-desktop-portal-hyprland || die "pacman failed. Check mirrors/network."

  say "Installing AUR packages if missing… (yay)"
  ensure_yay
  # QuickShell is in AUR
  yay -Sy --noconfirm --needed quickshell || die "Failed to install quickshell via yay."
  ok "Packages ready."
}

# --------------------------
# Paths
# --------------------------
CFG_DIR="$HOME_DIR/.config/quickshell/caelestia"
MOD_DIR="$CFG_DIR/modules"
SRC_ROOT="$HOME_DIR/.cache/caelestia-src"
MAIN_DIR="$SRC_ROOT/caelestia"
SHELL_DIR="$SRC_ROOT/shell"

mkdir -p "$SRC_ROOT" "$CFG_DIR" "$MOD_DIR" "$HOME_DIR/.local/bin"

# --------------------------
# Clone/refresh repos (full clone to keep tags)
# --------------------------
fetch_repos() {
  say "Fetching Caelestia repos… (full clone)"
  if [[ -d "$MAIN_DIR/.git" ]]; then
    (cd "$MAIN_DIR" && git fetch --all && git reset --hard origin/HEAD) || die "Refresh main repo failed."
  else
    git clone https://github.com/caelestia-dots/caelestia.git "$MAIN_DIR" || die "Clone main repo failed."
  fi

  if [[ -d "$SHELL_DIR/.git" ]]; then
    (cd "$SHELL_DIR" && git fetch --all && git reset --hard origin/HEAD) || die "Refresh shell repo failed."
  else
    git clone https://github.com/caelestia-dots/shell.git "$SHELL_DIR" || die "Clone shell repo failed."
  fi
  ok "Repos ready."
}

# --------------------------
# Install QuickShell config
# --------------------------
install_config() {
  say "Installing Caelestia QuickShell config…"

  # Try to locate shell.qml in shell repo (common layouts)
  SHELL_QML=""
  for p in \
    "$SHELL_DIR/shell.qml" \
    "$SHELL_DIR/shell/shell.qml" \
    "$SHELL_DIR/quickshell/shell.qml" \
    "$SHELL_DIR/caelestia/shell.qml"
  do
    [[ -f "$p" ]] && SHELL_QML="$p" && break
  done

  [[ -n "$SHELL_QML" ]] || die "Could not find shell.qml in the shell repo. Repo layout changed?"

  # Copy shell.qml
  install -Dm644 "$SHELL_QML" "$CFG_DIR/shell.qml"

  # Copy modules (prefer from shell repo; fallback to main repo)
  MOD_SRC=""
  for m in \
    "$SHELL_DIR/modules" \
    "$MAIN_DIR/modules"
  do
    [[ -d "$m" ]] && MOD_SRC="$m" && break
  done
  [[ -n "$MOD_SRC" ]] || die "Could not find a 'modules/' folder in shell or main repo."

  rm -rf "$MOD_DIR"
  mkdir -p "$MOD_DIR"
  cp -a "$MOD_SRC"/. "$MOD_DIR/"

  # Optionally copy assets if present (non-fatal)
  if [[ -d "$SHELL_DIR/assets" ]]; then
    mkdir -p "$CFG_DIR/assets"
    rsync -a --delete "$SHELL_DIR/assets/." "$CFG_DIR/assets/" 2>/dev/null || true
  fi

  ok "QuickShell config installed to: $CFG_DIR"
  ls -1 "$CFG_DIR" || true
}

# --------------------------
# Launcher (exports QML2_IMPORT_PATH)
# --------------------------
install_launcher() {
  say "Creating launcher ~/.local/bin/caelestia-shell …"
  LAUNCHER="$HOME_DIR/.local/bin/caelestia-shell"
  cat >"$LAUNCHER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
# Ensure our Caelestia QML modules are discoverable by QuickShell
export QML2_IMPORT_PATH="\$HOME/.config/quickshell/caelestia/modules:\${QML2_IMPORT_PATH:-}"
# Force native Wayland (Hyprland)
export QT_QPA_PLATFORM=wayland
exec quickshell -c "\$HOME/.config/quickshell/caelestia/shell.qml" "\$@"
EOF
  chmod +x "$LAUNCHER"
  ok "Launcher available: $LAUNCHER"

  # Ensure ~/.local/bin is in PATH for future logins
  if ! grep -qs 'PATH=.*/.local/bin' "$HOME_DIR/.profile" 2>/dev/null; then
    say "Adding ~/.local/bin to PATH in ~/.profile …"
    {
      echo ''
      echo '# Added by Caelestia installer'
      echo 'case ":$PATH:" in'
      echo '  *":$HOME/.local/bin:"*) ;;'
      echo '  *) export PATH="$HOME/.local/bin:$PATH" ;;'
      echo 'esac'
    } >> "$HOME_DIR/.profile"
  fi

  # Also export QML2_IMPORT_PATH in ~/.profile so kitty/runner shells inherit it
  if ! grep -qs 'QML2_IMPORT_PATH=.*/quickshell/caelestia/modules' "$HOME_DIR/.profile" 2>/dev/null; then
    echo 'export QML2_IMPORT_PATH="$HOME/.config/quickshell/caelestia/modules:${QML2_IMPORT_PATH:-}"' >> "$HOME_DIR/.profile"
  fi

  ok "PATH/QML2_IMPORT_PATH prepared for future sessions."
}

# --------------------------
# Hyprland autostart
# --------------------------
wire_hyprland() {
  HYPR="$HOME_DIR/.config/hypr/hyprland.conf"
  mkdir -p "$(dirname "$HYPR")"
  touch "$HYPR"

  if ! grep -qs 'exec-once *= *caelestia-shell' "$HYPR"; then
    say "Adding Hyprland autostart (exec-once = caelestia-shell)…"
    printf '\n# Caelestia autostart\nexec-once = caelestia-shell\n' >> "$HYPR"
  else
    ok "Hyprland autostart already present."
  fi
}

# --------------------------
# Run steps
# --------------------------
{
  install_packages
  fetch_repos
  install_config
  install_launcher
  wire_hyprland
  ok "All set."
  printf "\nUse inside Hyprland (Wayland session): \033[1mcaelestia-shell\033[0m\n\n"
  printf "If terminal says 'command not found', run: \033[1msource ~/.profile\033[0m once.\n"
  printf "If QuickShell reports QML types unavailable, you are probably not in Wayland.\n"
} 2>&1 | tee -a "$LOG"

exit 0