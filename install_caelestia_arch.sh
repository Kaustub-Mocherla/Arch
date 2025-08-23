#!/usr/bin/env bash
# Caelestia Shell one-shot installer for Arch Linux
# - Installs pacman + AUR deps (non-interactive, sane defaults)
# - Handles rust ↔ rustup conflict and JACK provider (uses pipewire-jack)
# - Clones the shell into ~/.config/quickshell/caelestia (with submodules)
# - Compiles & installs beat_detector (handles both possible source paths)
# - Sets Hyprland to autostart the shell
# - Installs & enables greetd + tuigreet to boot straight into Hyprland

set -euo pipefail

### ---------- helpers ----------
log(){ printf "\n\033[1;32m[+]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[!]\033[0m %s\n" "$*"; }
die(){ printf "\n\033[1;31m[x]\033[0m %s\n" "$*"; exit 1; }

[[ -f /etc/arch-release ]] || die "This script is for Arch Linux."

if [[ $EUID -eq 0 ]]; then
  die "Run as a normal user (not root). The script uses sudo where needed."
fi

command -v sudo >/dev/null || die "sudo is required."

P_CONF="--noconfirm --needed"
Y_CONF="--noconfirm --needed --answerdiff None --answerclean None"

### ---------- network manager (online + future GUI tools) ----------
log "Ensuring NetworkManager is present & active…"
sudo pacman -S $P_CONF networkmanager || true
sudo systemctl enable --now NetworkManager || true

### ---------- pacman base & wayland stack ----------
log "Installing official repo packages…"
sudo pacman -Syu $P_CONF \
  base-devel git hyprland alacritty wl-clipboard \
  ddcutil brightnessctl cava lm_sensors \
  qt6-declarative gcc-libs grim swappy libqalculate \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  aubio rustup xdg-desktop-portal-hyprland ttf-dejavu noto-fonts noto-fonts-emoji

# make rustup the active toolchain (avoid rust vs rustup conflict)
log "Configuring rustup toolchain…"
if pacman -Q rust &>/dev/null; then
  sudo pacman -Rns $P_CONF rust || true
fi
rustup default stable || true
rustup update || true

### ---------- install yay (if missing) ----------
if ! command -v yay >/dev/null; then
  log "Installing yay (AUR helper)…"
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si $P_CONF
  popd >/dev/null
  rm -rf "$tmpdir"
fi

### ---------- AUR packages ----------
log "Installing AUR packages…"
# Some names differ; try both where repos use -git variants.
aur_try_install() {
  for pkg in "$@"; do
    if yay -Si "$pkg" &>/dev/null; then
      yay -S $Y_CONF "$pkg"
    fi
  done
}
# Must be git version per README
aur_try_install quickshell-git
# CLI tool (name may be caelestia-cli or caelestia-cli-git)
aur_try_install caelestia-cli caelestia-cli-git
# Fonts & symbols
aur_try_install material-symbols-ttf caskaydia-cove-nerd-font
# Login greeter (greetd is in pacman; tuigreet is AUR)
sudo pacman -S $P_CONF greetd
aur_try_install tuigreet
# app2unit may be AUR in some mirrors
aur_try_install app2unit

### ---------- clone the shell into the expected location ----------
CFG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_DIR="$CFG_ROOT/quickshell"
SHELL_DIR="$QS_DIR/caelestia"

log "Fetching caelestia shell into $SHELL_DIR …"
mkdir -p "$QS_DIR"
if [[ -d "$SHELL_DIR/.git" ]]; then
  git -C "$SHELL_DIR" pull --recurse-submodules
  git -C "$SHELL_DIR" submodule update --init --recursive
else
  git clone --recurse-submodules https://github.com/caelestia-dots/shell.git "$SHELL_DIR"
fi

### ---------- build & install beat detector ----------
log "Building beat_detector…"
pushd "$SHELL_DIR" >/dev/null

# Find source in common locations (repo layout may vary)
BD_SRC=""
for p in assets/beat_detector.cpp assets/cpp/beat_detector.cpp; do
  [[ -f "$p" ]] && BD_SRC="$p" && break
done

if [[ -z "$BD_SRC" ]]; then
  warn "beat_detector.cpp not found in assets/ . Shell will still work, but the beat detector feature will be disabled."
else
  g++ -std=c++17 -Wall -Wextra \
    -I/usr/include/pipewire-0.3 \
    -I/usr/include/spa-0.2 \
    -I/usr/include/aubio \
    -o beat_detector "$BD_SRC" \
    -lpipewire-0.3 -laubio
  sudo install -Dm755 beat_detector /usr/lib/caelestia/beat_detector
fi
popd >/dev/null

### ---------- Hyprland autostart (exact command from README) ----------
log "Configuring Hyprland to autostart the Caelestia shell…"
mkdir -p "$CFG_ROOT/hypr"
HYPR_CFG="$CFG_ROOT/hypr/hyprland.conf"
if [[ -f "$HYPR_CFG" && -z "${FORCE_OVERWRITE_HYPR:-}" ]]; then
  if ! grep -q "caelestia shell -d" "$HYPR_CFG"; then
    printf "\n# Autostart Caelestia shell\nexec-once = caelestia shell -d\n" >> "$HYPR_CFG"
  fi
else
  cat > "$HYPR_CFG" << 'EOF'
# Minimal Hyprland config to launch the Caelestia shell
exec-once = caelestia shell -d
# Uncomment to fix flicker on some laptops:
# misc { vrr = 0 }
EOF
fi

### ---------- greetd (boot straight to Hyprland) ----------
log "Configuring greetd (tuigreet) for Hyprland login…"
sudo install -Dm644 /dev/stdin /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --remember --time --cmd Hyprland"
user = "greeter"
EOF
sudo systemctl enable greetd

### ---------- finish ----------
log "Done! Reboot to enter Hyprland + Caelestia shell."
echo "Tip:"
echo " - Put wallpapers in ~/Pictures/Wallpapers"
echo " - Set your profile picture at ~/.face"
echo " - If the shell needs IPC help: run 'caelestia shell -s' to list commands"
