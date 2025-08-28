#!/usr/bin/env bash
set -Eeuo pipefail

# ================================
# Caelestia Shell one-shot installer for Arch + Hyprland
# - Installs (or repairs) QuickShell
# - Clones caelestia-dots/shell into ~/.config/quickshell/caelestia
# - Ensures caelestia-dots/modules available
# - Wires Hyprland to autostart Caelestia
# - Works even if mirrors are slow; repairs common failures
# ================================

LOG="/var/log/caelestia_one_shot.log"
mkdir -p "$(dirname "$LOG")" || true
exec > >(tee -a "$LOG") 2>&1

c() { printf "\033[1;36m%s\033[0m\n" "$*"; }  # cyan
g() { printf "\033[1;32m%s\033[0m\n" "$*"; }  # green
y() { printf "\033[1;33m%s\033[0m\n" "$*"; }  # yellow
r() { printf "\033[1;31m%s\033[0m\n" "$*"; }  # red

need_root() { command -v sudo >/dev/null 2>&1 || { r "[x] sudo is required."; exit 1; }; }
pkg_ok() { pacman -Q "$1" >/dev/null 2>&1; }
aur_make() {
  local repo="$1"
  local dir="/tmp/aur-$(basename "$repo" .git)"
  rm -rf "$dir"; git clone --depth=1 "$repo" "$dir"
  (cd "$dir" && makepkg -si --noconfirm)
}

# 0) Preconditions
c "== Preflight =="
need_root
ping -c1 archlinux.org >/dev/null 2>&1 || { r "[x] No internet. Connect first."; exit 1; }

# 1) Pacman DB + reflector fallback
c "== Refreshing pacman databases (with reflector fallback) =="
if ! sudo pacman -Syy --noconfirm; then
  y "[!] pacman -Syy failed; trying reflector to refresh mirrors"
  if ! pkg_ok reflector; then sudo pacman -S --noconfirm reflector; fi
  sudo reflector --country India,Japan,Singapore --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
  sudo pacman -Syy --noconfirm
fi

# 2) Base deps
c "== Installing base dependencies =="
sudo pacman -S --noconfirm --needed \
  git curl unzip tar \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
  pipewire wireplumber \
  hyprland kitty

# 3) QuickShell install (repo or AUR fallback)
c "== Ensuring QuickShell is installed =="
if ! command -v quickshell >/dev/null 2>&1; then
  y "[!] quickshell not found. Trying pacman..."
  if ! sudo pacman -S --noconfirm quickshell; then
    y "[!] quickshell not in repos, building from AUR (quickshell-git)"
    # build toolchain
    sudo pacman -S --noconfirm --needed base-devel
    aur_make https://aur.archlinux.org/quickshell-git.git
  fi
else
  g "[v] quickshell already present."
fi

command -v quickshell >/dev/null 2>&1 || { r "[x] QuickShell still missing after install attempts."; exit 1; }

# 4) Caelestia Shell paths
CELE_DIR="$HOME/.config/quickshell/caelestia"
MOD_DIR="$CELE_DIR/modules"
mkdir -p "$CELE_DIR"

# 5) Clone/refresh Caelestia Shell
c "== Fetching Caelestia Shell (caelestia-dots/shell) =="
if [ -d "$CELE_DIR/.git" ]; then
  (cd "$CELE_DIR" && git pull --rebase --autostash || true)
else
  # clean stale content (if any)
  rm -rf "$CELE_DIR"
  mkdir -p "$CELE_DIR"
  if ! env -u GIT_ASKPASS -u SSH_ASKPASS git -c credential.helper= clone --depth=1 \
      https://github.com/caelestia-dots/shell.git "$CELE_DIR"; then
    y "[!] git clone failed; trying tarball download"
    tmp="$(mktemp -d)"
    curl -L https://api.github.com/repos/caelestia-dots/shell/tarball | tar -xz -C "$tmp"
    cp -r "$tmp"/*/* "$CELE_DIR"/
    rm -rf "$tmp"
  fi
fi

# 6) Clone/refresh Caelestia modules
c "== Fetching Caelestia modules (caelestia-dots/modules) =="
rm -rf "$MOD_DIR"
mkdir -p "$MOD_DIR"
if ! env -u GIT_ASKPASS -u SSH_ASKPASS git -c credential.helper= clone --depth=1 \
    https://github.com/caelestia-dots/modules.git "$MOD_DIR"; then
  y "[!] git clone of modules failed; trying tarball"
  tmp="$(mktemp -d)"
  curl -L https://api.github.com/repos/caelestia-dots/modules/tarball | tar -xz -C "$tmp"
  cp -r "$tmp"/*/* "$MOD_DIR"/
  rm -rf "$tmp"
fi

# 7) Sanity fix: ensure main QML exists
SHELL_QML="$CELE_DIR/shell.qml"
if [ ! -f "$SHELL_QML" ]; then
  r "[x] $SHELL_QML not found; Caelestia shell pull failed."
  exit 1
fi

# 8) Autostart Caelestia in Hyprland
c "== Wiring Hyprland autostart for Caelestia =="
HYPR_DIR="$HOME/.config/hypr"
HYPR_USER_CONF="$HYPR_DIR/hypr-user.conf"
mkdir -p "$HYPR_DIR"
touch "$HYPR_USER_CONF"

# remove previous exec-once quickshell lines to avoid duplicates
sed -i '/quickshell -c caelestia/d' "$HYPR_USER_CONF" || true
echo 'exec-once = quickshell -c caelestia' >> "$HYPR_USER_CONF"

# 9) Create helper command `caelestia-shell`
c "== Creating helper wrapper 'caelestia-shell' in ~/.local/bin =="
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'EOF'
#!/usr/bin/env bash
exec quickshell -c caelestia
EOF
chmod +x "$HOME/.local/bin/caelestia-shell"

# 10) PATH hint
case ":${PATH}:" in
  *":$HOME/.local/bin:"*) ;;
  *) y "[!] ~/.local/bin is not in PATH for this shell. Add it to your shell rc if needed." ;;
esac

# 11) Final guidance
g "[v] All set."
cat <<EOF

• Caelestia files:
  - Shell:   $CELE_DIR
  - Modules: $MOD_DIR
  - Main QML: $SHELL_QML

• Autostart:
  Hyprland will now run Caelestia at login via:
    $HYPR_USER_CONF  (contains: exec-once = quickshell -c caelestia)

• Launch manually (inside Wayland/Hyprland):
    quickshell -c caelestia
  or:
    caelestia-shell

• If you still see only a triangles splash, open a terminal (kitty) and run:
    quickshell -c caelestia

Log saved to: $LOG
EOF