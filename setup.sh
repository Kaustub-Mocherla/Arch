bash -c '
set -euo pipefail

# ---- Pretty printing helpers ----
info(){ printf "\033[1;36m[ i ]\033[0m %s\n" "$*"; }
ok(){   printf "\033[1;32m[ ✓ ]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[ ! ]\033[0m %s\n" "$*"; }
err(){  printf "\033[1;31m[ x ] %s\033[0m\n" "$*" >&2; }

# ---- 0) Root check for system operations ----
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    err "Please install sudo (or run as root)."; exit 1
  fi
else
  SUDO=""
fi

# ---- 1) Basic network sanity ----
info "Checking internet connectivity…"
if ! ping -c1 archlinux.org >/dev/null 2>&1; then
  warn "Ping failed; trying with curl DNS resolver test…"
  if ! curl -sI https://archlinux.org >/dev/null 2>&1; then
    err "No internet. Connect to Wi-Fi/Ethernet and re-run."; exit 1
  fi
fi
ok "Internet looks good."

# ---- 2) Core packages (pacman) ----
info "Installing core packages (pacman)…"
$SUDO pacman -Sy --noconfirm --needed \
  base-devel git curl wget \
  networkmanager \
  hyprland \
  wl-clipboard grim swappy \
  ddcutil brightnessctl \
  cava lm_sensors fish \
  qt6-declarative libpipewire libqalculate \
  gcc-libs

# Optional but very helpful on Wayland:
$SUDO pacman -Sy --noconfirm --needed \
  xdg-desktop-portal-hyprland || true

# Enable NetworkManager
info "Enabling NetworkManager…"
$SUDO systemctl enable --now NetworkManager || true
ok "Core done."

# ---- 3) Install yay (AUR helper) if missing ----
if ! command -v yay >/dev/null 2>&1; then
  info "Installing yay (AUR helper)…"
  tmpdir="$(mktemp -d)"; trap "rm -rf \"$tmpdir\"" EXIT
  (
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  )
  ok "yay installed."
fi

# ---- 4) AUR packages required by Caelestia shell ----
# (exact names from Caelestia README, with AUR variants where needed)
info "Installing AUR/extra deps for Caelestia Shell…"
yay -S --noconfirm --needed \
  quickshell-git \
  caelestia-cli-git \
  ttf-caskaydia-cove-nerd \
  ttf-material-symbols || warn "Some optional AUR packages may have failed; continuing."

ok "Dependencies step finished."

# ---- 5) Clone Caelestia Shell to the correct location ----
CFG_DIR="${HOME}/.config/quickshell"
DEST="${CFG_DIR}/caelestia"
info "Cloning Caelestia Shell repo into: $DEST"
mkdir -p "$CFG_DIR"
if [[ -d "$DEST/.git" ]]; then
  info "Repo already exists; pulling latest…"
  git -C "$DEST" pull --rebase --autostash || warn "git pull had issues; continuing."
else
  git clone https://github.com/caelestia-dots/shell.git "$DEST"
fi
ok "Repo ready."

# ---- 6) Beat detector (optional) ----
# Only build if the source file exists in the repo
BD_SRC="$DEST/assets/beat_detector.cpp"
BD_OUT="/usr/lib/caelestia/beat_detector"
if [[ -f "$BD_SRC" ]]; then
  info "Building beat detector…"
  $SUDO mkdir -p /usr/lib/caelestia
  g++ -std=c++17 -Wall -Wextra \
    -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \
    -o beat_detector "$BD_SRC" -lpipewire-0.3 -laubio
  $SUDO mv beat_detector "$BD_OUT"
  ok "Beat detector installed to $BD_OUT"
else
  warn "Beat detector source not found in repo; skipping build (this is okay)."
fi

# ---- 7) Fonts cache + wallpapers folder ----
info "Updating font cache & making wallpapers dir…"
$SUDO fc-cache -f >/dev/null 2>&1 || true
mkdir -p "${HOME}/Pictures/Wallpapers"

# ---- 8) Hyprland autostart for Caelestia shell ----
HYPR_DIR="${HOME}/.config/hypr"
HYPR_CONF="${HYPR_DIR}/hyprland.conf"
mkdir -p "$HYPR_DIR"
if [[ -f "$HYPR_CONF" ]]; then
  if ! grep -q "qs -c caelestia" "$HYPR_CONF"; then
    info "Adding Caelestia autostart to existing hyprland.conf"
    printf "\n# Autostart Caelestia shell\nexec-once = qs -c caelestia\n" >> "$HYPR_CONF"
  else
    info "Autostart line already present."
  fi
else
  info "Creating a minimal hyprland.conf with Caelestia autostart…"
  cat > "$HYPR_CONF" <<EOF
# Minimal Hyprland config
monitor=,preferred,auto,1
exec-once = qs -c caelestia
EOF
fi

# ---- 9) Final tips ----
cat <<TIP

\033[1;32mAll done (no fatal errors)\033[0m

• To launch the shell manually (inside your Wayland session):
    \033[1;36mqs -c caelestia\033[0m
  or
    \033[1;36mcaelestia shell -d\033[0m

• Hyprland autostarts Caelestia now (via your Hyprland config).

• If wallpapers or fonts look off, you can (re)install optional AUR fonts:
    \033[1;36myay -S ttf-caskaydia-cove-nerd ttf-material-symbols\033[0m

• Start Hyprland from a TTY with:
    \033[1;36mHyprland\033[0m
  (or pick Hyprland from your display manager if you use one)

Logs (if you need them): \033[1;36mjournalctl -b\033[0m and \033[1;36m~/.local/share/yay/*/log\033[0m
TIP
'