#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/caelestia_repair.log"
TS() { date "+%F %T"; }
log() { echo -e "[$(TS)] $*" | tee -a "$LOG"; }
ok()  { log "\e[32m[✔]\e[0m $*"; }
warn(){ log "\e[33m[!]\e[0m $*"; }
err() { log "\e[31m[x]\e[0m $*"; }

NEED_ROOT_CMDS=(pacman)
for c in "${NEED_ROOT_CMDS[@]}"; do
  command -v "$c" >/dev/null || { err "Required command '$c' not found."; exit 1; }
done

# ---- 0) Quick sanity: internet (don’t hard fail, but warn)
if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
  ok "Internet OK"
else
  warn "No ping to archlinux.org — continuing, but pacman/AUR may fail."
fi

# ---- 1) System refresh & essential packages
log "Refreshing system packages…"
sudo pacman -Syu --needed --noconfirm | tee -a "$LOG"

log "Installing core deps for QuickShell (Qt6, Wayland, GPU, tools)…"
sudo pacman -S --needed --noconfirm \
  base-devel git \
  qt6-declarative qt6-wayland qt6-shadertools qt6-5compat \
  libxkbcommon wayland-protocols \
  pipewire wireplumber \
  hyprland kitty wl-clipboard xdg-desktop-portal-hyprland \
  mesa vulkan-radeon libva-mesa-driver 2>/dev/null | tee -a "$LOG" || true

# ---- 2) AUR helper (prefer paru, else yay, else bootstrap paru-bin)
aur_helper=""
if command -v paru >/dev/null 2>&1; then
  aur_helper="paru"
elif command -v yay >/dev/null 2>&1; then
  aur_helper="yay"
else
  warn "No AUR helper found — bootstrapping paru-bin…"
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/paru-bin.git
  pushd paru-bin >/dev/null
  makepkg -si --noconfirm | tee -a "$LOG"
  popd >/dev/null
  popd >/dev/null
  rm -rf "$tmpdir"
  aur_helper="paru"
fi
ok "Using AUR helper: $aur_helper"

# ---- 3) (Re)install QuickShell from AUR
log "Installing/rebuilding quickshell-git…"
if ! $aur_helper -S --noconfirm --needed quickshell-git 2>&1 | tee -a "$LOG"; then
  warn "AUR helper failed — fallback to manual makepkg for quickshell-git."
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  git clone https://aur.archlinux.org/quickshell-git.git
  cd quickshell-git
  makepkg -si --noconfirm | tee -a "$LOG"
  popd >/dev/null
  rm -rf "$tmpdir"
fi
ok "QuickShell installed."

# ---- 4) Create Caelestia config dir if missing, and fetch latest shell (optional)
conf_root="$HOME/.config/quickshell/caelestia"
mkdir -p "$conf_root"
# Don’t overwrite user config if present
if [ ! -f "$conf_root/shell.qml" ]; then
  warn "Caelestia QML not found; leaving as-is (your dots repo should have placed it)."
fi

# ---- 5) Wire Caelestia to Hyprland autostart
hypr_conf="$HOME/.config/hypr/hyprland.conf"
mkdir -p "$(dirname "$hypr_conf")"
touch "$hypr_conf"

if grep -qE '^\s*exec-once\s*=\s*quickshell\s+-c\s+caelestia\b' "$hypr_conf"; then
  ok "Hyprland already autostarts Caelestia."
else
  echo '' >> "$hypr_conf"
  echo '# Autostart Caelestia shell UI' >> "$hypr_conf"
  echo 'exec-once = quickshell -c caelestia' >> "$hypr_conf"
  ok "Added Caelestia autostart to Hyprland."
fi

# ---- 6) Quick self-test (headless safe)
log "Running QuickShell self-test…"
if quickshell -c caelestia --help >/dev/null 2>&1; then
  ok "QuickShell command present."
else
  err "QuickShell not runnable. Check $LOG for AUR build errors."
fi

cat <<'EONOTE'

────────────────────────────────────────────────────────
✅ Repair complete.

• You can launch Caelestia now (inside Wayland/Hyprland):
    quickshell -c caelestia

• Caelestia will autostart next login because we added:
    exec-once = quickshell -c caelestia
  to  ~/.config/hypr/hyprland.conf

• If you’re currently at a TTY, log into Hyprland (e.g. via greetd/tuigreet)
  or run:  Hyprland

• Logs:
    /var/log/caelestia_repair.log
────────────────────────────────────────────────────────
EONOTE

exit 0