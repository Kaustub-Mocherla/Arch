#!/usr/bin/env bash
set -euo pipefail

# ---------- sanity ----------
if ! command -v sudo >/dev/null 2>&1; then
  echo "[!] sudo is required." >&2; exit 1
fi
if ! grep -qi arch /etc/os-release; then
  echo "[!] This script is for Arch/Arch-based systems." >&2; exit 1
fi

USER_NAME="${USER}"
HOME_DIR="${HOME}"
QS_CONF_DIR="${HOME_DIR}/.config/quickshell/caelestia"
AUR_CACHE="${HOME_DIR}/.cache/aur"
BUILD_DIR="${HOME_DIR}/.cache/caelestia-build"
PATH_BIN="${HOME_DIR}/.local/bin"

mkdir -p "${AUR_CACHE}" "${BUILD_DIR}" "${PATH_BIN}"
mkdir -p "${HOME_DIR}/.config" "${HOME_DIR}/.local/share"

# ---------- pacman deps ----------
echo "[i] Installing pacman dependencies…"
sudo pacman -Syu --needed --noconfirm \
  git base-devel cmake ninja \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  gcc-libs glibc curl unzip tar \
  ddcutil brightnessctl cava networkmanager \
  fish aubio libqalculate swappy

# ---------- helper: AUR install without yay ----------
aur_install () {
  local pkg="$1"
  local dir="${AUR_CACHE}/${pkg}"
  if pacman -Qq "${pkg}" >/dev/null 2>&1; then
    echo "[v] ${pkg} already installed."
    return 0
  fi
  echo "[i] Building AUR package: ${pkg}"
  rm -rf "${dir}"
  git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "${dir}"
  pushd "${dir}" >/dev/null
  # Build as user (NOT sudo). makepkg will ask for sudo only when installing.
  makepkg -si --noconfirm --needed
  popd >/dev/null
}

# quickshell-git is recommended by the shell README
aur_install quickshell-git || true
# CLI is used by the launcher (`caelestia shell …`)
aur_install caelestia-cli || true
# Fonts mentioned in README (names can vary; try AUR first, ignore failures)
aur_install material-symbols || true
aur_install nerd-fonts-caskaydia-cove || true
# app2unit may be in AUR
aur_install app2unit || true

# ---------- clone Caelestia shell sources to Quickshell config ----------
echo "[i] Cloning Caelestia shell repo…"
mkdir -p "$(dirname "${QS_CONF_DIR}")"
if [ -d "${QS_CONF_DIR}/.git" ]; then
  echo "[i] Repo already present; pulling latest…"
  git -C "${QS_CONF_DIR}" fetch --all --prune
  git -C "${QS_CONF_DIR}" reset --hard origin/main
else
  git clone https://github.com/caelestia-dots/shell.git "${QS_CONF_DIR}"
fi

# ---------- build & install Caelestia shell (plugin + config) ----------
echo "[i] Building Caelestia shell (CMake + Ninja)…"
pushd "${QS_CONF_DIR}" >/dev/null

# Clean any old build
rm -rf build
mkdir -p build

# Install the Quickshell config into ~/.config/quickshell/caelestia
# (plugin and libs still install to system dirs via CMAKE_INSTALL_PREFIX=/)
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/ \
  -DINSTALL_QSCONFDIR="${QS_CONF_DIR}"

cmake --build build
sudo cmake --install build

# Ensure you own the config tree (system install can create root-owned files)
sudo chown -R "${USER_NAME}:${USER_NAME}" "${QS_CONF_DIR}"
popd >/dev/null

# ---------- launcher ----------
echo "[i] Writing launcher…"
LAUNCHER="${PATH_BIN}/caelestia-shell"
cat > "${LAUNCHER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Make sure our user config (with QML modules) is on the import path
CE_DIR="$HOME/.config/quickshell/caelestia"
export QML2_IMPORT_PATH="$CE_DIR/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

# Prefer Wayland
export QT_QPA_PLATFORM=wayland

# Start the shell via the CLI (preferred) or fall back to quickshell.
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
EOF
chmod +x "${LAUNCHER}"

# ---------- Hyprland autostart (idempotent) ----------
HYPRCONF="${HOME_DIR}/.config/hypr/hyprland.conf"
mkdir -p "$(dirname "${HYPRCONF}")"
touch "${HYPRCONF}"
if ! grep -q 'caelestia-shell' "${HYPRCONF}"; then
  echo "[i] Adding exec-once to Hyprland config…"
  {
    echo ""
    echo "# Caelestia shell autostart"
    echo "exec-once = ${LAUNCHER}"
  } >> "${HYPRCONF}"
fi

echo
echo "[v] Done."
echo "• Quickshell version: $(quickshell --version | head -n1 || true)"
echo "• Caelestia config:   ${QS_CONF_DIR}"
echo "• Launcher:           ${LAUNCHER}"
echo
echo "Now, inside a Hyprland (Wayland) session, run:"
echo "    caelestia-shell"
echo
echo "If you still see 'module qs.* is not installed', it means the plugin"
echo "did not get picked up. In that case, run:"
echo "    QML2_IMPORT_PATH=${QS_CONF_DIR}/modules:${QML2_IMPORT_PATH:-} caelestia-shell"