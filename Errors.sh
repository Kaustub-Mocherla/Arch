#!/usr/bin/env bash
# fix_caelestia.sh
# One-shot repair for Caelestia + QuickShell on Hyprland (AMD GPU / Qt Wayland issues)

set -euo pipefail

TITLE="Caelestia Repair"
LOG="${HOME}/caelestia_repair_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG"

green() { printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
red()   { printf "\033[1;31m%s\033[0m\n" "$*"; }
step()  { echo -e "\n\033[1;36m==> $*\033[0m" | tee -a "$LOG"; }

need_root_pkgs=(mesa vulkan-radeon libva-mesa-driver qt6-wayland qt6-declarative qt6-quick3d qt6-shadertools qt6-quickcontrols2 pipewire wireplumber)
aur_pkgs=(quickshell-git)             # QuickShell is AUR
optional_aur=(caelestia-cli-git)      # optional CLI utilities (safe to skip if it fails)

#--- helpers -------------------------------------------------------
have_cmd(){ command -v "$1" >/dev/null 2>&1; }
ensure_dir(){ mkdir -p "$1"; }
append_line_once(){
  local file="$1" line="$2"
  ensure_dir "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"
  grep -Fxq "$line" "$file" || echo "$line" >> "$file"
}

as_root(){
  if [[ $EUID -ne 0 ]]; then sudo bash -c "$*"; else bash -c "$*"; fi
}

install_pacman(){
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "Installing (pacman): ${pkgs[*]}"
  as_root "pacman -Syu --needed --noconfirm ${pkgs[*]}" | tee -a "$LOG"
}

install_yay(){
  if have_cmd yay; then
    step "yay is present."
    return 0
  fi
  step "Installing yay (AUR helper)…"
  install_pacman git base-devel
  tmpd="$(mktemp -d)"
  trap 'rm -rf "$tmpd"' EXIT
  git -C "$tmpd" clone --depth=1 https://aur.archlinux.org/yay-bin.git | tee -a "$LOG"
  ( cd "$tmpd/yay-bin" && makepkg -si --noconfirm ) | tee -a "$LOG"
  green "yay installed."
}

install_aur(){
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  step "Installing (AUR): ${pkgs[*]}"
  yay -S --needed --noconfirm "${pkgs[@]}" | tee -a "$LOG"
}

#--- 0) sanity ------------------------------------------------------
step "$TITLE — starting"
green "Log: $LOG"

if ! have_cmd hyprland; then
  yellow "Hyprland not detected — installing…"
  install_pacman hyprland kitty
fi

# AMD GPU?
if lspci | grep -iqE 'AMD/ATI|Advanced Micro Devices'; then
  step "AMD GPU detected — ensuring Mesa/Vulkan stack."
  install_pacman mesa vulkan-radeon libva-mesa-driver
else
  yellow "AMD GPU not detected. Skipping AMD-specific Vulkan package."
fi

# Qt Wayland & multimedia
install_pacman "${need_root_pkgs[@]}"

#--- 1) ensure AUR + QuickShell -----------------------------------
install_yay
install_aur "${aur_pkgs[@]}"
# Optional: try Caelestia CLI helpers, but don't fail if it breaks
if ! install_aur "${optional_aur[@]}"; then
  yellow "Optional package(s) failed (ok to ignore): ${optional_aur[*]}"
fi

#--- 2) Wayland-friendly env for Qt/Gtk ----------------------------
step "Configuring Wayland/Qt environment"
envd="${HOME}/.config/environment.d"
ensure_dir "$envd"
cat > "${envd}/qt-wayland.conf" <<'EOF'
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt6ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
XDG_SESSION_TYPE=wayland
EOF

append_line_once "${HOME}/.profile" 'export PATH="$HOME/.local/bin:$PATH"'

#--- 3) make sure Caelestia config exists --------------------------
step "Ensuring Caelestia QuickShell config path"
qs_cfg="${HOME}/.config/quickshell/caelestia"
ensure_dir "$qs_cfg"
# If there is not a shell.qml yet, create a minimal loader that points to your Caelestia setup;
# You can replace this with the official shell later.
if [[ ! -f "${qs_cfg}/shell.qml" ]]; then
  cat > "${qs_cfg}/shell.qml" <<'QML'
import QtQuick
Item {
  // Placeholder: you can swap this with Caelestia shell repo contents.
  // Keeps QuickShell from crashing on missing config.
}
QML
fi

#--- 4) autostart QuickShell from Hyprland -------------------------
step "Wiring QuickShell autostart in Hyprland"
hyprconf="${HOME}/.config/hypr/hyprland.conf"
ensure_dir "$(dirname "$hyprconf")"
touch "$hyprconf"

# Remove old lines that used xcb by accident
sed -i '/qs -c caelestia/d' "$hyprconf" || true
sed -i '/quickshell -c caelestia/d' "$hyprconf" || true

append_line_once "$hyprconf" 'env = QT_QPA_PLATFORM,wayland'
append_line_once "$hyprconf" 'exec-once = quickshell -c caelestia'

#--- 5) a small CLI to test without logging in ---------------------
step "Installing a tiny tester CLI: qs-test"
ensure_dir "${HOME}/.local/bin"
cat > "${HOME}/.local/bin/qs-test" <<'SH'
#!/usr/bin/env bash
set -e
export QT_QPA_PLATFORM=wayland
exec quickshell -c caelestia
SH
chmod +x "${HOME}/.local/bin/qs-test"

#--- 6) final checks -----------------------------------------------
step "Final checks"
if ! have_cmd quickshell; then
  red "quickshell not found in PATH — something went wrong with AUR install."
  exit 1
fi

# show GPU + Qt summary
echo "GPU: $(lspci | grep -iE 'VGA.*AMD|3D.*AMD|ATI' || echo 'unknown')" | tee -a "$LOG"
echo "Qt Wayland libs:" | tee -a "$LOG"
pacman -Q qt6-wayland qt6-declarative qt6-quick3d qt6-quickcontrols2 qt6-shadertools 2>/dev/null | tee -a "$LOG" || true

green "All done. Reboot recommended."

cat <<'EONEXT'

Next:
  1) Reboot:   reboot
  2) Log into the Hyprland session (Wayland).
  3) QuickShell should autostart (exec-once) and load Caelestia.

If QuickShell doesn’t show, press:
  - SUPER + Enter  to open terminal
  - Run:   qs-test    (starts QuickShell with Wayland env)
  - Or:    quickshell -c caelestia

Logs:
  - QuickShell logs under:  ~/.cache/quickshell/crashes/  and  /run/user/$UID/quickshell/*/log.qslog
  - This script log:         '"$LOG"'

Tip:
  Replace ~/.config/quickshell/caelestia with the official Caelestia shell files
  (shell.qml, components, assets) for the full UI.

EONEXT