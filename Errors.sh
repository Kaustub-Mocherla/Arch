#!/usr/bin/env bash
# Caelestia Shell (Hyprland + Quickshell) one-shot installer for Arch
# - Handles network, pacman lock, base deps
# - Installs AUR packages (via yay/paru if present, else raw makepkg)
# - Clones Caelestia UI to ~/.config/quickshell/caelestia
# - Autostarts it from Hyprland
# - Leaves a log at /var/log/caelestia_one_shot.log (root only) or ~/caelestia_one_shot.log

set -Eeuo pipefail

# -------- pretty printing --------
c_grn="\033[1;32m"; c_cyn="\033[1;36m"; c_red="\033[1;31m"; c_yel="\033[1;33m"; c_end="\033[0m"
info(){ echo -e "${c_cyn}[i]${c_end} $*"; }
ok(){   echo -e "${c_grn}[v]${c_end} $*"; }
warn(){ echo -e "${c_yel}[!]${c_end} $*"; }
err(){  echo -e "${c_red}[x]${c_end} $*"; }

# -------- logging --------
LOG="/var/log/caelestia_one_shot.log"
if ! { : >>"$LOG"; } 2>/dev/null; then
  LOG="$HOME/caelestia_one_shot.log"
fi
exec > >(tee -a "$LOG") 2>&1

# -------- helpers --------
need_root(){ [ "$EUID" -ne 0 ] && err "Run as root (sudo ./script)." && exit 1; }
has(){ command -v "$1" >/dev/null 2>&1; }

# We’ll call sudo for system tasks; allow root or sudo.
SUDO="sudo"
if [ "$EUID" -eq 0 ]; then SUDO=""; fi

# -------- 0) quick preflight --------
info "Starting Caelestia one-shot installer…  (log: $LOG)"

# Internet?
if ping -c 2 archlinux.org >/dev/null 2>&1; then
  ok "Internet looks OK."
else
  warn "Network ping failed. Trying again via curl HEAD…"
  if ! curl -I --max-time 8 https://archlinux.org >/dev/null 2>&1; then
    err "No network connectivity. Connect to Wi-Fi/Ethernet and re-run."
    exit 1
  fi
  ok "Internet reachable."
fi

# -------- 1) handle pacman DB/lock --------
info "Refreshing pacman databases…"
if [ -e /var/lib/pacman/db.lck ]; then
  warn "Pacman lock found; removing stale lock."
  $SUDO rm -f /var/lib/pacman/db.lck || true
fi
$SUDO pacman -Sy --noconfirm || { err "pacman -Sy failed."; exit 1; }

# -------- 2) core packages --------
info "Installing base packages…"
$SUDO pacman -S --needed --noconfirm \
  base-devel git curl wget \
  networkmanager \
  pipewire wireplumber pipewire-alsa pipewire-pulse \
  qt6-declarative grim slurp swappy wl-clipboard \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  cava ddcutil brightnessctl lm_sensors fish || {
    err "Base package install failed."; exit 1; }

# Enable NetworkManager (if not already)
$SUDO systemctl enable --now NetworkManager >/dev/null 2>&1 || true

# -------- 3) AUR install helper (if needed) --------
aur_makepkg_install() {
  # $1 = pkgname (from AUR)
  local pkg="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  info "AUR: building $pkg with makepkg (no helper)."
  pushd "$tmpdir" >/dev/null
  git clone "https://aur.archlinux.org/${pkg}.git"
  cd "$pkg"
  # makepkg needs a non-root user; if we are root, add --asroot only if makepkg supports (older disallowed).
  # Safer path: use 'nobody' via sudo -u if root.
  if [ "$EUID" -eq 0 ]; then
    sudo -u nobody bash -lc "cd '$PWD' && makepkg -si --noconfirm"
  else
    makepkg -si --noconfirm
  fi
  popd >/dev/null
  rm -rf "$tmpdir"
}

aur_install() {
  # Usage: aur_install pkg1 pkg2 …
  local pkgs=("$@")
  local helper=""
  if has yay; then helper="yay"
  elif has paru; then helper="paru"
  fi

  if [ -n "$helper" ]; then
    info "Installing AUR packages with $helper: ${pkgs[*]}"
    $helper -S --needed --noconfirm "${pkgs[@]}" || warn "Some AUR packages via $helper failed (continuing)."
  else
    for p in "${pkgs[@]}"; do
      if pacman -Qi "$p" >/dev/null 2>&1; then
        ok "AUR package already installed: $p"
      else
        aur_makepkg_install "$p" || warn "AUR build failed for $p (continuing)."
      fi
    done
  fi
}

# -------- 4) Quickshell + Caelestia CLI (AUR) --------
# Quickshell is required and is AUR (git variant). Caelestia CLI is AUR too.
info "Installing Quickshell + Caelestia CLI (AUR)…"
aur_install quickshell-git caelestia-cli-git || true

# Fallback: if quickshell not present after AUR attempt, try repo (in case you have a custom repo)
if ! has qs; then
  warn "Quickshell not in PATH yet. Trying 'pacman -S quickshell' (if available)…"
  $SUDO pacman -S --noconfirm --needed quickshell || true
fi
if ! has qs; then
  err "Quickshell is not installed. Install 'quickshell-git' from AUR manually and re-run."
  exit 1
fi
ok "Quickshell ready."

# -------- 5) Optional fonts for exact look (AUR). Non-fatal. --------
info "Attempting to install optional fonts (for exact Caelestia look)…"
aur_install ttf-caskaydia-cove-nerd ttf-material-symbols || true

# -------- 6) Place Caelestia shell sources where Quickshell expects --------
info "Cloning Caelestia Shell UI to ~/.config/quickshell/caelestia …"
CAEDIR="$HOME/.config/quickshell/caelestia"
mkdir -p "$HOME/.config/quickshell"
if [ -d "$CAEDIR/.git" ]; then
  info "Repo exists; pulling latest…"
  git -C "$CAEDIR" pull --ff-only || warn "Git pull failed; keeping existing files."
else
  # Backup any existing non-git dir
  if [ -d "$CAEDIR" ]; then
    mv "$CAEDIR" "${CAEDIR}.bak.$(date +%s)"
  fi
  git clone https://github.com/caelestia-dots/shell.git "$CAEDIR"
fi
ok "Caelestia UI in place."

# -------- 7) Autostart from Hyprland --------
info "Enabling Caelestia autostart in Hyprland…"
mkdir -p "$HOME/.config/hypr"
HCONF="$HOME/.config/hypr/hyprland.conf"
touch "$HCONF"

if ! grep -qE '(^|\s)exec-once\s*=\s*qs\s*-c\s*caelestia' "$HCONF" && \
   ! grep -qE '(^|\s)exec-once\s*=\s*caelestia\s+shell' "$HCONF"; then
  echo 'exec-once = qs -c caelestia' >> "$HCONF"
  ok "Added: exec-once = qs -c caelestia"
else
  ok "Autostart already present."
fi

# -------- 8) Services sanity --------
$SUDO systemctl enable --now wireplumber >/dev/null 2>&1 || true
# (xdg-desktop-portal-hyprland spawns on Wayland session; nothing to enable here)

# -------- 9) Final tips --------
cat <<'TIP'

========================================================
 Caelestia set up ✔

Next steps:

1) Log out of the TTY and log in to the **Hyprland** session.
   Caelestia should auto-launch (sidebar + dashboard/media).
   If you’re already in Hyprland, you can start manually:
     qs -c caelestia
   (Or add/remove features in ~/.config/quickshell/caelestia)

2) If you see only a wallpaper, check logs:
     journalctl --user -xe | grep -i quickshell -n

3) Optional cosmetics (fonts) were attempted via AUR. If skipped,
   install later:  ttf-caskaydia-cove-nerd  ttf-material-symbols

Log file:  /var/log/caelestia_one_shot.log  (or ~/caelestia_one_shot.log)
========================================================
TIP

ok "All done."