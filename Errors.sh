#!/usr/bin/env bash
# Caelestia + Quickshell one-shot installer/repair
set -Eeuo pipefail
IFS=$'\n\t'

LOG="$HOME/caelestia_one_shot.log"
exec > >(tee -a "$LOG") 2>&1

say(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\n\033[1;31m[x]\033[0m %s\n' "$*"; exit 1; }

# -- privilege runner: sudo if present, else su --
asroot() {
  if command -v sudo >/dev/null 2>&1; then
    sudo bash -c "$*"
  else
    # If we're already root, just run it; else use su -c
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then bash -c "$*"; else su -c "$*"; fi
  fi
}

say "Caelestia/Quickshell one-shot — log: $LOG"

# 0) Basic network sanity (DNS + HTTPS)
say "Checking internet…"
if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
  warn "Ping failed. Trying HTTPS head…"
  if ! curl -fsSI https://archlinux.org >/dev/null; then
    die "No network / DNS. Connect Wi-Fi or plug in ethernet, then re-run."
  fi
fi
ok "Internet looks good."

# 1) Sync pacman db (non-interactive)
say "Refreshing package database…"
asroot "pacman -Sy --noconfirm" || die "pacman -Sy failed"

# 2) Install core bits (no AUR here)
# qt6-quickcontrols2 does not exist on Arch; the QuickControls2 types are in qt6-declarative
PKGS=(
  git curl wget base-devel
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools qt6-quick3d
  pipewire wireplumber
  xdg-user-dirs
)

# GPU helpers (optional but nice)
if lspci | grep -qi 'AMD/ATI'; then PKGS+=(mesa vulkan-radeon libva-mesa-driver); fi
if lspci | grep -qi 'NVIDIA';  then PKGS+=(nvidia-utils); fi
if lspci | grep -qi 'Intel';   then PKGS+=(mesa vulkan-intel libva-intel-driver); fi

say "Installing core dependencies…"
asroot "pacman -S --needed --noconfirm ${PKGS[*]}" || warn "Some packages may already be installed."

# 3) Install Quickshell (repo or AUR)
say "Ensuring QuickShell is installed…"
if ! command -v quickshell >/dev/null 2>&1; then
  # try repo first
  if asroot "pacman -S --needed --noconfirm quickshell"; then
    ok "Installed quickshell from repo."
  else
    warn "quickshell not in repos. Installing yay and using AUR…"
    if ! command -v yay >/dev/null 2>&1; then
      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT
      asroot "pacman -S --needed --noconfirm go" || true
      git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$workdir/yay-bin"
      ( cd "$workdir/yay-bin" && makepkg -si --noconfirm )
      ok "Installed yay."
    fi
    yay -S --needed --noconfirm quickshell || die "AUR install of quickshell failed"
    ok "Installed quickshell from AUR."
  fi
else
  ok "quickshell already present."
fi

# 4) Install Caelestia shell config
CFG_DIR="$HOME/.config/quickshell/caelestia"
say "Fetching Caelestia shell config into: $CFG_DIR"
mkdir -p "$(dirname "$CFG_DIR")"
if [[ -d "$CFG_DIR/.git" ]]; then
  (cd "$CFG_DIR" && git pull --rebase --autostash) || warn "git pull had issues; continuing."
else
  git clone --depth=1 https://github.com/caelestia-dots/shell "$CFG_DIR" || die "Clone failed"
fi
ok "Caelestia files are in place."

# 5) Create a simple launcher in ~/.local/bin
say "Creating launcher: caelestia-shell"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/caelestia-shell" <<'EOF'
#!/usr/bin/env bash
# Run Caelestia inside Wayland/Hyprland
exec quickshell -c caelestia "$@"
EOF
chmod +x "$BIN_DIR/caelestia-shell"
# Persist PATH for this session:
case ":$PATH:" in *":$BIN_DIR:"*) : ;; *) export PATH="$BIN_DIR:$PATH";; esac
ok "Launcher installed at $BIN_DIR/caelestia-shell"

# 6) Autostart in Hyprland
say "Adding Hyprland autostart (exec-once)…"
mkdir -p "$HOME/.config/hypr"
HYPR="$HOME/.config/hypr/hyprland.conf"
touch "$HYPR"
if ! grep -q 'quickshell -c caelestia' "$HYPR"; then
  printf '\n# Caelestia shell\nexec-once = quickshell -c caelestia\n' >> "$HYPR"
  ok "Added exec-once to $HYPR"
else
  ok "Hyprland already set to autostart Caelestia."
fi

# 7) Optional: tiny sanity check of QML types by launching under Wayland only
say "Done. IMPORTANT:"
cat <<MSG

• You must run Caelestia **inside Wayland** (e.g. Hyprland). From a TTY:
    Hyprland

• Once in Hyprland, Caelestia should auto-start (we added exec-once).
  You can also launch manually:
    quickshell -c caelestia
    or
    caelestia-shell

• If you only see a black/triangle “splash”, Caelestia probably isn't running.
  Open a terminal (Super+Enter if kitty), and run:
    quickshell -c caelestia

• Full log saved to: $LOG
MSG
ok "All set."