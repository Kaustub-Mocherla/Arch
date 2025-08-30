#!/usr/bin/env bash
set -euo pipefail

# =============== Pretty output helpers ===============
say()  { printf "\033[1;36m[i]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[v]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# =============== Sanity ===============
USER_NAME="${USER:-$(id -un)}"
HOME_DIR="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
[[ -n "${HOME_DIR}" ]] || die "Cannot resolve HOME directory."

if [[ ! -t 1 ]]; then
  warn "No TTY detected. Running non-interactive."
fi

# Paths
CFG_DIR="${HOME_DIR}/.config/quickshell/caelestia"
MODULES_DIR="${CFG_DIR}/modules"
BIN_DIR="${HOME_DIR}/.local/bin"
LAUNCHER="${BIN_DIR}/caelestia-shell"
QSCONF_DIR="${HOME_DIR}/.config/quickshell"
SHELL_REPO_URL="https://github.com/caelestia-dots/shell"
WORK_DIR="${HOME_DIR}/.cache/caelestia-build"
LOG_FILE="${HOME_DIR}/caelestia_shell_install.log"

mkdir -p "${WORK_DIR}" "${BIN_DIR}" "${QSCONF_DIR}"

# =============== Need root for pacman (but NOT for makepkg) ===============
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

if ! have_cmd sudo && [[ $EUID -ne 0 ]]; then
  die "This script needs 'sudo' for package installs. Install 'sudo' or run as root."
fi

pac() {
  if [[ $EUID -eq 0 ]]; then
    pacman "$@"
  else
    sudo pacman "$@"
  fi
}

# =============== Update mirrors (best effort) ===============
say "Refreshing pacman databases…"
pac -Sy || warn "pacman -Sy failed once; continuing."

# =============== Base packages needed no matter what ===============
PKGS=(
  git curl unzip tar base-devel
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools
  pipewire wireplumber kitty
)

say "Installing/updating required packages (pacman)…"
if ! pac -S --needed --noconfirm "${PKGS[@]}"; then
  warn "Some packages failed via pacman (maybe already installed or repo hiccup)."
fi

# =============== QuickShell (repo or AUR) ===============
QS_PKG="quickshell"

if pac -Si "${QS_PKG}" >/dev/null 2>&1; then
  say "Installing QuickShell from official repos…"
  pac -S --needed --noconfirm "${QS_PKG}" || die "Failed to install QuickShell."
else
  say "QuickShell not in official repos; installing from AUR via yay…"

  if ! have_cmd yay; then
    say "Bootstrapping yay (AUR helper)…"
    YSRC="${WORK_DIR}/yay"
    rm -rf "${YSRC}"
    git clone --depth=1 https://aur.archlinux.org/yay.git "${YSRC}" || die "Failed to clone yay."
    pushd "${YSRC}" >/dev/null
    # makepkg MUST NOT run as root
    if [[ $EUID -eq 0 ]]; then
      die "makepkg cannot run as root. Re-run this script as your user (with sudo available)."
    fi
    makepkg -si --noconfirm || die "Failed to build/install yay."
    popd >/dev/null
  else
    ok "yay already present."
  fi

  say "Installing QuickShell from AUR via yay…"
  yay -S --needed --noconfirm "${QS_PKG}" || die "Failed to install QuickShell via yay."
fi

ok "QuickShell ready."

# =============== Fetch Caelestia Shell (includes modules/) ===============
say "Cloning Caelestia Shell repo (contains modules/)…"
rm -rf "${WORK_DIR}/shell"
git clone --depth=1 "${SHELL_REPO_URL}" "${WORK_DIR}/shell" \
  || die "Failed to clone ${SHELL_REPO_URL}"

# Validate expected content
if [[ ! -f "${WORK_DIR}/shell/shell.qml" ]]; then
  die "shell.qml not found in shell repo. Repo structure may have changed."
fi
if [[ ! -d "${WORK_DIR}/shell/modules" ]]; then
  die "modules/ folder not found in shell repo. This is required for Caelestia QML components."
fi

# =============== Install into QuickShell config ===============
say "Placing Caelestia config into ${CFG_DIR} …"
rm -rf "${CFG_DIR}"
mkdir -p "${CFG_DIR}"
cp -a "${WORK_DIR}/shell/"* "${CFG_DIR}/" || die "Failed to copy shell files."

ok "Config copied."
ok "Found modules in: ${MODULES_DIR}"

# =============== Create launcher wrapper that sets QML2_IMPORT_PATH ===============
say "Creating launcher ${LAUNCHER} …"
cat > "${LAUNCHER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFG="${HOME}/.config/quickshell/caelestia"
QML_IMPORTS="${CFG}/modules"

export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland
# Make sure QuickShell can find the Caelestia QML module
if [[ -d "${QML_IMPORTS}" ]]; then
  export QML2_IMPORT_PATH="${QML_IMPORTS}:${QML2_IMPORT_PATH:-}"
fi

exec quickshell -c caelestia
EOF
chmod +x "${LAUNCHER}"

# Ensure ~/.local/bin is on PATH for future logins
if ! grep -q '\.local/bin' "${HOME_DIR}/.profile" 2>/dev/null; then
  say "Adding ~/.local/bin to PATH in ~/.profile …"
  {
    echo ''
    echo '# Add user bin to PATH'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "${HOME_DIR}/.profile"
fi

# Try to source current shell if possible
if [[ -n "${BASH_VERSION:-}" && -f "${HOME_DIR}/.profile" ]]; then
  # shellcheck disable=SC1090
  source "${HOME_DIR}/.profile" || true
fi

ok "Launcher available as: ${LAUNCHER}"
ok "You can now run: caelestia-shell"

# =============== Hyprland autostart (optional, safe) ===============
HYPR_DIR="${HOME_DIR}/.config/hypr"
HYPR_USER="${HYPR_DIR}/hypr-user.conf"
HYPR_MAIN="${HYPR_DIR}/hyprland.conf"

mkdir -p "${HYPR_DIR}"

autoline='exec-once = quickshell -c caelestia'

add_autostart() {
  local file="$1"
  touch "$file"
  if ! grep -Fq "${autoline}" "$file" 2>/dev/null; then
    printf '\n# Caelestia autostart\n%s\n' "${autoline}" >> "$file"
    ok "Added autostart to $file"
  else
    ok "Autostart already present in $file"
  fi
}

if [[ -f "${HYPR_MAIN}" ]]; then
  add_autostart "${HYPR_MAIN}"
else
  add_autostart "${HYPR_USER}"
fi

# =============== Final checks & tips ===============
say "Verifying QuickShell runs (headless check)…"
if quickshell -v >/dev/null 2>&1; then
  ok "QuickShell binary looks good."
else
  warn "QuickShell not runnable from this TTY; continue inside Wayland session."
fi

cat > "${LOG_FILE}" <<EOFLOG
Caelestia Shell install log
User: ${USER_NAME}
Config: ${CFG_DIR}
Modules: ${MODULES_DIR}
Launcher: ${LAUNCHER}

If QuickShell shows "module Caelestia is not installed":
  1) Confirm modules exist: ${MODULES_DIR}
  2) Run: echo \$QML2_IMPORT_PATH
     It should include '${MODULES_DIR}'
  3) Launch with: ${LAUNCHER}

EOFLOG

echo
ok "All set."

cat <<'NEXT'

To start Caelestia **now** (inside Hyprland/Wayland), run:
  caelestia-shell

If you're on the splash triangles, press:
  Super + Enter   (opens kitty)
then run:
  caelestia-shell

It will also **autostart** next Hyprland login via:
  exec-once = quickshell -c caelestia

Troubleshooting:
- If you still see "Type Background/FileDialog … unavailable":
  * you're likely not in Wayland, or
  * QML2_IMPORT_PATH isn't set at runtime.
  Use the provided "caelestia-shell" launcher, not bare "quickshell".

- If kitty never opens on Super+Enter, your Hyprland binds may be different.
  Try switching TTY (Ctrl+Alt+F3), log in, then `startx` / login greeter, then run
  `caelestia-shell` from a terminal inside Wayland.

Enjoy 🌸
NEXT