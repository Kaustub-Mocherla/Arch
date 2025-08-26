#!/usr/bin/env bash
set -euo pipefail

#############################
# Caelestia Shell Installer #
#############################

LOGFILE="/var/log/caelestia_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

# ---------- UI helpers ----------
c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_off='\033[0m'
info(){ echo -e "${c_cyan}[i]${c_off} $*"; }
ok(){ echo -e "${c_green}[✓]${c_off} $*"; }
warn(){ echo -e "${c_yellow}[!]${c_off} $*"; }
fail(){ echo -e "${c_red}[x]${c_off} $*"; }

error_exit(){ fail "$*"; echo "See log: $LOGFILE"; exit 1; }

# ---------- effective user / sudo ----------
if [[ $EUID -ne 0 ]]; then
  error_exit "Run as root: sudo bash install.sh"
fi
SUDO='' # we are root
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  warn "Can't detect a non-root login user; using root's home. User-specific files will land in /root."
  REAL_USER="root"
fi
USER_HOME="$(eval echo "~$REAL_USER")"

# ---------- variables ----------
PACMAN_RETRIES=3
AUR_RETRIES=2
MIRRORLIST="/etc/pacman.d/mirrorlist"

# Caelestia shell repo (do not change unless you know why)
CAELESTIA_SHELL_REPO="https://github.com/caelestia-dots/shell.git"
QS_DEST_DIR="$USER_HOME/.config/quickshell"
SHELL_DEST_DIR="$QS_DEST_DIR/caelestia"

# ---------- small helpers ----------
retry() {
  local tries="$1"; shift
  local n=1
  until "$@"; do
    if (( n >= tries )); then return 1; fi
    warn "Command failed (attempt $n/$tries): $*"
    sleep $((2*n))
    ((n++))
  done
}

have() { command -v "$1" >/dev/null 2>&1; }

write_static_mirrors() {
  info "Writing static mirror fallbacks..."
  cat >"$MIRRORLIST" <<'EOF'
Server = https://mirror.i3d.net/archlinux/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://archlinux.mirror.liteserver.nl/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://mirror.pkgbuild.com/$repo/os/$arch
EOF
}

# ---------- network checks ----------
info "Checking internet connectivity..."
if ! retry 2 ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
  error_exit "No network (ICMP failed). Connect Wi-Fi/Ethernet first."
fi
ok "Internet (ICMP) is reachable."

info "Checking DNS resolution (github.com)..."
if ! retry 2 getent hosts github.com >/dev/null; then
  warn "DNS lookup failed; trying to add temporary resolver 1.1.1.1"
  echo "nameserver 1.1.1.1" >/etc/resolv.conf
  if ! getent hosts github.com >/dev/null; then
    error_exit "DNS still failing. Fix network/DNS and re-run."
  fi
fi
ok "DNS OK."

# ---------- mirrors & pacman sync ----------
info "Configuring pacman mirrors..."
write_static_mirrors

if ! retry "$PACMAN_RETRIES" pacman -Syy --noconfirm; then
  warn "Initial mirror sync failed. Will keep static mirrors."
else
  ok "Mirror DBs synced."
fi

# Try reflector to optimize (best effort)
if ! have reflector; then
  info "Installing reflector (best-effort)..."
  pacman -S --needed --noconfirm reflector || warn "reflector install failed; staying with static mirrors."
fi
if have reflector; then
  info "Optimizing mirrors with reflector (India/nearby, fallback to latest 20)..."
  if ! reflector --country India --country Singapore --country 'United States' \
       --age 12 --protocol https --sort rate --save "$MIRRORLIST" 2>/dev/null; then
    warn "reflector tuning failed; keeping static mirrors."
  else
    ok "Mirrorlist tuned by reflector."
    pacman -Syy --noconfirm || true
  fi
fi

# ---------- core packages ----------
CORE_PKGS=(
  base-devel git curl wget ca-certificates archlinux-keyring
  networkmanager pipewire wireplumber pipewire-alsa pipewire-pulse
  ddcutil brightnessctl cava lm_sensors fish qt6-declarative
  gcc-libs libpipewire
)

info "Installing core packages..."
if ! retry "$PACMAN_RETRIES" pacman -S --needed --noconfirm "${CORE_PKGS[@]}"; then
  error_exit "Core packages failed to install."
fi
ok "Core packages installed."

# enable NetworkManager
info "Enabling NetworkManager..."
systemctl enable --now NetworkManager || warn "Could not enable NetworkManager (maybe in a container)."

# ---------- Bootstrap yay (AUR helper) ----------
if ! su - "$REAL_USER" -c 'command -v yay' >/dev/null 2>&1; then
  info "Bootstrapping yay (AUR helper) for user: $REAL_USER"
  su - "$REAL_USER" -c "rm -rf \$HOME/yay-build && mkdir -p \$HOME/yay-build"
  if ! su - "$REAL_USER" -c "cd \$HOME/yay-build && git clone https://aur.archlinux.org/yay-bin.git"; then
    error_exit "Failed to clone yay-bin AUR."
  fi
  if ! su - "$REAL_USER" -c "cd \$HOME/yay-build/yay-bin && makepkg -si --noconfirm"; then
    error_exit "Failed to build/install yay."
  fi
  ok "yay installed."
else
  ok "yay is already installed."
fi

# ---------- AUR packages needed for shell ----------
AUR_PKGS_REQ=( quickshell-git caelestia-cli-git )
AUR_PKGS_OPT=( xdg-desktop-portal-hyprland ttf-caskaydia-cove-nerd ttf-material-symbols )

info "Installing required AUR packages via yay..."
if ! su - "$REAL_USER" -c "yay -S --needed --noconfirm ${AUR_PKGS_REQ[*]}"; then
  error_exit "Installing required AUR packages failed."
fi
ok "Required AUR packages installed."

info "Installing optional AUR packages (best-effort)..."
su - "$REAL_USER" -c "yay -S --needed --noconfirm ${AUR_PKGS_OPT[*]}" || warn "Some optional AUR packages failed; continuing."

# ---------- Clone Caelestia Shell ----------
info "Preparing Caelestia shell destination..."
su - "$REAL_USER" -c "mkdir -p '$QS_DEST_DIR'"

if [[ -d "$SHELL_DEST_DIR/.git" ]]; then
  info "Updating existing $SHELL_DEST_DIR..."
  su - "$REAL_USER" -c "cd '$SHELL_DEST_DIR' && git pull --ff-only" || warn "git pull failed; keeping current tree."
else
  info "Cloning Caelestia Shell repo..."
  if ! su - "$REAL_USER" -c "git clone --depth 1 '$CAELESTIA_SHELL_REPO' '$SHELL_DEST_DIR'"; then
    error_exit "Failed to clone $CAELESTIA_SHELL_REPO"
  fi
fi
ok "Caelestia Shell sources ready at $SHELL_DEST_DIR"

# ---------- Build beat detector ----------
BD_SRC_REL="assets/beat_detector.cpp"
BD_SRC="$SHELL_DEST_DIR/$BD_SRC_REL"
BD_OUT="/usr/lib/caelestia/beat_detector"

if [[ -f "$BD_SRC" ]]; then
  info "Building beat detector..."
  mkdir -p "$(dirname "$BD_OUT")"
  TMP_BUILD="$(mktemp -d)"
  # Build under user's env to ensure headers are visible; then move with root
  if su - "$REAL_USER" -c "g++ -std=c++17 -Wall -Wextra \
        -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \
        -o '$TMP_BUILD/beat_detector' '$BD_SRC' -lpipewire-0.3 -laubio"; then
    install -m 0755 "$TMP_BUILD/beat_detector" "$BD_OUT"
    rm -rf "$TMP_BUILD"
    ok "Beat detector installed at $BD_OUT"
  else
    warn "Beat detector build failed. Shell will still work, but audio-reactive features may be disabled."
    warn "You can retry later with:
      g++ -std=c++17 -Wall -Wextra -I/usr/include/pipewire-0.3 -I/usr/include/spa-0.2 -I/usr/include/aubio \\
         -o ~/beat_detector '$BD_SRC' -lpipewire-0.3 -laubio && sudo install -m 0755 ~/beat_detector $BD_OUT"
  fi
else
  warn "Beat detector source '$BD_SRC_REL' not found in repo; skipping build."
fi

# ---------- Final tips ----------
cat <<EOF

${c_green}All done (no fatal errors)!${c_off}

• To launch the shell manually (inside your Wayland session):
    ${c_cyan}qs -c caelestia${c_off}
  or
    ${c_cyan}caelestia shell -d${c_off}

• If you're using Hyprland and the full dots, the shell can autostart via Hyprland config.

• If wallpapers or fonts look off, install optional AUR fonts (already attempted):
    ${c_cyan}yay -S ttf-caskaydia-cove-nerd ttf-material-symbols${c_off}

• Log file: ${c_cyan}$LOGFILE${c_off}

EOF

ok "Caelestia Shell setup complete."
exit 0