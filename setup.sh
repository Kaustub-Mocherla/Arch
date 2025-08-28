#!/usr/bin/env bash
# setup_caelestia.sh
# One-shot installer/repairer for Hyprland + Caelestia (quickshell) on Arch

set -Eeuo pipefail
IFS=$'\n\t'

LOG="/var/log/caelestia_full_setup.log"
mkdir -p "$(dirname "$LOG")" || true
exec > >(tee -a "$LOG") 2>&1

green(){ printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
red(){ printf "\033[1;31m%s\033[0m\n" "$*"; }
die(){ red "[x] $*"; exit 1; }

need_root(){
  if [[ $EUID -ne 0 ]]; then
    die "Run this script with: sudo ./setup_caelestia.sh"
  fi
}

need_internet(){
  if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    yellow "[!] Internet looks down; trying 1.1.1.1"
    ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || die "No internet connectivity. Connect Wi-Fi/Ethernet and re-run."
  fi
  green "[✓] Internet OK"
}

fix_mirrors(){
  yellow "[i] Refreshing pacman mirrors (reflector)..."
  pacman -Sy --noconfirm reflector || true
  if command -v reflector >/dev/null 2>&1; then
    reflector --country 'India,United States,Singapore' \
      --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
    green "[✓] Mirrors refreshed (or kept as-is)"
  else
    yellow "[i] reflector not installed; continuing with current mirrors"
  fi
}

pacman_install(){
  local pkgs=("$@")
  pacman -S --needed --noconfirm "${pkgs[@]}"
}

ensure_yay(){
  if ! command -v yay >/dev/null 2>&1; then
    yellow "[i] Installing yay (AUR helper)…"
    pacman_install git base-devel || true
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    pushd "$tmpdir" >/dev/null
      sudo -u "$(logname)" git clone https://aur.archlinux.org/yay.git
      chown -R "$(logname)":"$(logname)" yay
      cd yay
      sudo -u "$(logname)" makepkg -si --noconfirm
    popd >/dev/null
  fi
  green "[✓] yay is ready"
}

install_pkg(){
  # Try pacman first, fall back to yay for AUR-only packages
  local pkg="$1"
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    pacman_install "$pkg"
  else
    yellow "[i] $pkg not in repos, trying AUR via yay…"
    sudo -u "$(logname)" yay -S --needed --noconfirm "$pkg" || die "Failed to install $pkg"
  fi
}

ensure_user_dirs(){
  local user home
  user="$(logname)"
  home="$(getent passwd "$user" | cut -d: -f6)"
  mkdir -p "$home/.config" "$home/.local/bin" "$home/.config/quickshell" "$home/.config/hypr"
  chown -R "$user":"$user" "$home/.config" "$home/.local"
}

clone_caelestia(){
  local user home target
  user="$(logname)"
  home="$(getent passwd "$user" | cut -d: -f6)"
  target="$home/.config/quickshell/caelestia"
  if [[ -d "$target/.git" ]]; then
    yellow "[i] Updating existing Caelestia clone…"
    sudo -u "$user" git -C "$target" pull --rebase || true
  else
    yellow "[i] Cloning Caelestia shell…"
    sudo -u "$user" git clone --depth=1 https://github.com/caelestia-dots/shell "$target"
  fi
  chown -R "$user":"$user" "$target"
  green "[✓] Caelestia shell ready at $target"
}

wire_hyprland_autostart(){
  local user home hyprconf
  user="$(logname)"
  home="$(getent passwd "$user" | cut -d: -f6)"
  hyprconf="$home/.config/hypr/hyprland.conf"

  touch "$hyprconf"
  chown "$user":"$user" "$hyprconf"

  # Remove previous lines we manage
  sudo -u "$user" sed -i '/# CAELESTIA-BEGIN/,/# CAELESTIA-END/d' "$hyprconf" || true

  cat <<'HYPR' | sudo -u "$user" tee -a "$hyprconf" >/dev/null
# CAELESTIA-BEGIN (managed by setup_caelestia.sh)
env = XDG_CURRENT_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland

# Make sure portals exist for file pickers / screenshots
exec-once = /usr/lib/xdg-desktop-portal-hyprland & sleep 1 && /usr/lib/xdg-desktop-portal &

# Start the Quickshell Caelestia shell
exec-once = qs -c caelestia
# CAELESTIA-END
HYPR

  green "[✓] Hyprland will autostart Caelestia (qs -c caelestia)"
}

make_manual_launcher(){
  local user home
  user="$(logname)"
  home="$(getent passwd "$user" | cut -d: -f6)"

  cat <<'EOS' | tee /usr/local/bin/caelestia-run >/dev/null
#!/usr/bin/env bash
set -euo pipefail
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland,x11
exec qs -c caelestia
EOS
  chmod +x /usr/local/bin/caelestia-run
  green "[✓] Manual launcher: caelestia-run"
}

main(){
  need_root
  need_internet
  fix_mirrors

  yellow "[i] System update…"
  pacman -Syu --noconfirm

  # Essentials from repos
  pacman_install \
    hyprland kitty git curl wget networkmanager \
    qt6-wayland qt6-svg qt6-declarative \
    xdg-desktop-portal xdg-desktop-portal-hyprland

  systemctl enable --now NetworkManager || true

  ensure_yay

  # AUR / special packages
  install_pkg quickshell
  # In case user mirrors didn’t have this in repo
  if ! pacman -Qi qt6-quickcontrols2 >/dev/null 2>&1; then
    install_pkg qt6-quickcontrols2
  fi

  ensure_user_dirs
  clone_caelestia
  wire_hyprland_autostart
  make_manual_launcher

  green ""
  green "=============================================="
  green "  All done. Reboot, log into **Hyprland**."
  green "  Caelestia should appear automatically."
  green ""
  green "  If something goes wrong in-session:"
  green "    Super+Q (or open kitty) and run:  caelestia-run"
  green ""
  green "  Full log: $LOG"
  green "=============================================="
}

main "$@"