#!/usr/bin/env bash
# caelestia_full_reset.sh
set -Eeuo pipefail

LOG="${HOME}/caelestia_full_reset.log"
exec > >(awk '{ print strftime("[%F %T]"), $0 }' | tee -a "$LOG") 2>&1

say() { printf "\033[1;36m[*]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*"; }
die(){ err "$*"; exit 1; }

REPO_SHELL_ZIP="https://codeload.github.com/caelestia-dots/shell/zip/refs/heads/main"
REPO_MODULES_ZIP="https://codeload.github.com/caelestia-dots/modules/zip/refs/heads/main"

QS_DIR="${HOME}/.config/quickshell/caelestia"
QS_MOD_DIR="${QS_DIR}/modules"
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"

require_root_tools() {
  command -v sudo >/dev/null || die "sudo is required."
  command -v pacman >/dev/null || die "This script is for Arch/Arch-like systems."
}

check_network() {
  say "Checking network…"
  if ping -c1 archlinux.org >/dev/null 2>&1; then
    ok "Internet reachable."
  else
    die "No internet connectivity. Connect first and re-run."
  fi
  say "Enabling NTP time sync…"
  sudo timedatectl set-ntp true || warn "timedatectl failed (non-fatal)."
}

fix_tmp() {
  say "Ensuring /tmp permissions (1777)…"
  sudo chmod 1777 /tmp || die "Failed to set /tmp permissions."
}

base_packages() {
  say "Installing/refreshing base packages…"
  sudo pacman -Syy --noconfirm || warn "pacman -Syy had warnings."
  sudo pacman -S --needed --noconfirm \
    git curl unzip rsync base-devel \
    qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
    pipewire wireplumber \
    hyprland kitty || warn "Some packages were already present or optional."
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already installed."
    return
  fi
  say "Installing yay (AUR helper)…"
  # Build as normal user
  mkdir -p "${HOME}/builds"; cd "${HOME}/builds"
  rm -rf yay
  git clone https://aur.archlinux.org/yay.git
  cd yay
  # makepkg must NOT be run as root
  makepkg -si --noconfirm || die "Failed to build/install yay."
  ok "yay installed."
}

install_quickshell() {
  if command -v quickshell >/dev/null 2>&1; then
    ok "QuickShell already present."
    return
  fi
  say "Installing QuickShell from AUR…"
  yay -S --noconfirm quickshell || die "Failed to install quickshell (AUR)."
  ok "QuickShell installed."
}

reset_shell_dirs() {
  say "Resetting Caelestia directories…"
  rm -rf "${QS_DIR}"
  mkdir -p "${QS_MOD_DIR}"
  ok "Folders ready at ${QS_DIR}"
}

fetch_and_unpack() {
  local zip_url="$1" dest_dir="$2" tmp_zip
  tmp_zip="$(mktemp --suffix=.zip)"
  say "Downloading: ${zip_url}"
  curl -fL --connect-timeout 20 --retry 3 -o "${tmp_zip}" "${zip_url}" \
    || die "Download failed: ${zip_url}"
  say "Unpacking into ${dest_dir}"
  unzip -q -o "${tmp_zip}" -d /tmp/_czip
  # Move contents (handle unknown top-level folder name)
  local top="$(find /tmp/_czip -maxdepth 1 -mindepth 1 -type d | head -n1)"
  [[ -d "$top" ]] || die "Unpack produced no folder?"
  rsync -a --delete "${top}/" "${dest_dir}/"
  rm -rf "${tmp_zip}" /tmp/_czip
  ok "Fetched into ${dest_dir}"
}

install_shell_content() {
  say "Fetching Caelestia Shell (QML config + assets)…"
  fetch_and_unpack "${REPO_SHELL_ZIP}" "${QS_DIR}"
  say "Fetching Caelestia Modules…"
  fetch_and_unpack "${REPO_MODULES_ZIP}" "${QS_MOD_DIR}"
}

wire_hypr_autostart() {
  if [[ -f "${HYPR_CONF}" ]]; then
    say "Adding QuickShell autostart to Hyprland config…"
    if ! grep -q 'quickshell -c caelestia' "${HYPR_CONF}"; then
      printf '\n# Caelestia: autostart QuickShell\nexec-once = quickshell -c caelestia\n' \
        >> "${HYPR_CONF}"
      ok "Added exec-once to ${HYPR_CONF}"
    else
      ok "Hyprland exec-once already present."
    fi
    if ! grep -q 'bind = SUPER, S, exec, quickshell -c caelestia' "${HYPR_CONF}"; then
      printf 'bind = SUPER, S, exec, quickshell -c caelestia\n' >> "${HYPR_CONF}"
      ok "Added SUPER+S launcher."
    fi
  else
    warn "Hyprland config not found at ${HYPR_CONF}. Skipping autostart wiring."
  fi
}

validate_quickshell() {
  say "Validating QuickShell binary…"
  quickshell -v || warn "quickshell -v had warnings."
  say "Testing config load (dry run)…"
  if quickshell -c caelestia --no-window >/dev/null 2>&1; then
    ok "Caelestia config parse OK."
  else
    warn "Parse test returned non-zero; will still try to run inside Wayland session."
  fi
}

main() {
  require_root_tools
  check_network
  fix_tmp
  base_packages
  install_yay
  install_quickshell
  reset_shell_dirs
  install_shell_content
  wire_hypr_autostart
  validate_quickshell

  cat <<EOF

====================================================
[✓] All done.

• If you're already in a Hyprland session, run:
    quickshell -c caelestia

• Otherwise, log into Hyprland (greetd/tuigreet/SDDM),
  and Caelestia should autostart (we added exec-once).

• Stocks widget you installed earlier still works.

Log file: ${LOG}
====================================================
EOF
}

main "$@"