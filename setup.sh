#!/usr/bin/env bash
# Caelestia: one-shot installer/repairer for the Caelestia UI (quickshell)
# - Clones FULL git history & tags (fixes: "VERSION is not set and failed to get from git")
# - Builds Caelestia Shell with CMake+Ninja
# - Copies Caelestia modules and sets QML2_IMPORT_PATH
# - Creates a 'caelestia-shell' launcher
# - Adds Hyprland exec-once so it autostarts next login
# Run as your normal user. You'll be prompted for sudo when needed.

set -Eeuo pipefail

### ---- pretty prints ----
c() { printf "\033[1;36m%s\033[0m\n" "$*"; }  # cyan
g() { printf "\033[1;32m%s\033[0m\n" "$*"; }  # green
y() { printf "\033[1;33m%s\033[0m\n" "$*"; }  # yellow
r() { printf "\033[1;31m%s\033[0m\n" "$*"; }  # red

### ---- variables ----
MAIN_REPO="https://github.com/caelestia-dots/caelestia.git"
SHELL_REPO="https://github.com/caelestia-dots/shell.git"

# where we keep clean clones to build from (with full history & tags)
SRC_DIR="${HOME}/.cache/caelestia-src"
SHELL_SRC="${SRC_DIR}/shell"
MAIN_SRC="${SRC_DIR}/caelestia"

# quickshell runtime config dir
QS_CFG_DIR="${HOME}/.config/quickshell"
CAE_CFG_DIR="${QS_CFG_DIR}/caelestia"
MODULES_DIR="${CAE_CFG_DIR}/modules"

# local “install” locations for user (no root)
QML_DIR="${HOME}/.local/share/qt6/qml"
LIB_DIR="${HOME}/.local/lib"

LAUNCH_DIR="${HOME}/.local/bin"
LAUNCHER="${LAUNCH_DIR}/caelestia-shell"

HYPR_DIR="${HOME}/.config/hypr"
HYPR_USER_CONF="${HYPR_DIR}/hyprland.conf"           # common name
HYPR_USER_ALT="${HYPR_DIR}/hypr.conf"                # alt name; we’ll patch whichever exists

LOG="/var/log/caelestia_one_shot.log"
mkdir -p "$(dirname "$LOG")" || true

trap 'r "[x] Failed. See: $LOG"' ERR

logrun() { # tee both console and log
  { echo -e "\n==> $*"; "$@"; } 2>&1 | tee -a "$LOG"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { y "[i] Installing missing: $1"; return 1; }
}

### ---- 0) pacman deps (quickshell & build toolchain) ----
c "== Installing/updating required packages (pacman) =="
sudo true >/dev/null 2>&1 || true

# Base build + qt6 pieces + Hyprland + terminal + tooling
PKGS=(
  git cmake ninja base-devel curl unzip tar
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools
  hyprland kitty pipewire wireplumber wl-clipboard
  # quickshell (if available from your repos)
  quickshell
)

if ! sudo pacman -Syu --needed --noconfirm "${PKGS[@]}" 2>&1 | tee -a "$LOG" | grep -qi "error: target not found: quickshell"; then
  :
else
  y "[!] 'quickshell' not in your pacman repos. If you don’t already have it, install via AUR (quickshell-bin/quickshell-git) with yay/paru, or install from source separately."
fi

### ---- 1) ensure dirs ----
mkdir -p "$SRC_DIR" "$CAE_CFG_DIR" "$MODULES_DIR" "$LAUNCH_DIR" "$QML_DIR" "$LIB_DIR"

### ---- 2) fresh FULL clone of repos (with tags) ----
c "== Fetching Caelestia repos (FULL clone, no depth) =="
# main (optional modules/examples)
if [ ! -d "$MAIN_SRC/.git" ]; then
  logrun git clone "$MAIN_REPO" "$MAIN_SRC"
else
  (cd "$MAIN_SRC" && logrun git fetch --all --tags && logrun git reset --hard origin/HEAD)
fi

# shell (must be full to get tags for version)
if [ ! -d "$SHELL_SRC/.git" ]; then
  logrun git clone "$SHELL_REPO" "$SHELL_SRC"
else
  (cd "$SHELL_SRC" && logrun git fetch --all --tags && logrun git reset --hard origin/HEAD)
fi
# make sure tags exist (fixes: VERSION is not set…)
(cd "$SHELL_SRC" && logrun git fetch --tags)

### ---- 3) build & install Caelestia shell (user-local) ----
c "== Building Caelestia shell (CMake + Ninja) =="
BUILD_DIR="$SHELL_SRC/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
(
  cd "$SHELL_SRC"
  logrun cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    -DINSTALL_QMLDIR="$QML_DIR" \
    -DINSTALL_LIBDIR="$LIB_DIR" \
    -DINSTALL_QSCONFDIR="$CAE_CFG_DIR"
  logrun cmake --build build
  logrun cmake --install build
)

### ---- 4) copy modules into QuickShell config ----
# The shell repo includes a top-level 'modules' folder. Use that if present.
c "== Copying Caelestia modules =="
if [ -d "$SHELL_SRC/modules" ]; then
  rsync -a --delete "$SHELL_SRC/modules/" "$MODULES_DIR/" | tee -a "$LOG"
  g "[v] Using modules from shell repo."
elif [ -d "$MAIN_SRC/modules" ]; then
  rsync -a --delete "$MAIN_SRC/modules/" "$MODULES_DIR/" | tee -a "$LOG"
  g "[v] Using modules from main repo."
else
  r "[x] No 'modules/' folder found in either repo. The shell can’t load its QML types."
  exit 1
fi

### ---- 5) ensure shell.qml exists (installed by step 3) ----
if [ ! -f "$CAE_CFG_DIR/shell.qml" ]; then
  r "[x] shell.qml not found at $CAE_CFG_DIR/shell.qml (install step should have placed it)."
  r "   Check the build log in $LOG."
  exit 1
fi

### ---- 6) launcher that sets QML2_IMPORT_PATH and runs quickshell ----
c "== Creating 'caelestia-shell' launcher =="
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="${HOME}/.config/quickshell/caelestia/shell.qml"
MOD="${HOME}/.config/quickshell/caelestia/modules"
export QML2_IMPORT_PATH="${MOD}${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
exec quickshell -c "$CFG"
EOF
chmod +x "$LAUNCHER"

# Also add ~/.local/bin to PATH if not already in user shells
for f in "${HOME}/.profile" "${HOME}/.bash_profile" "${HOME}/.zprofile"; do
  [ -f "$f" ] || continue
  if ! grep -q 'PATH=.*/.local/bin' "$f"; then
    printf '\n# add user bin to path for Caelestia\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$f"
  fi
done

### ---- 7) Hyprland autostart (exec-once) ----
c "== Adding Hyprland exec-once autostart =="
TARGET_CONF=""
if [ -f "$HYPR_USER_CONF" ]; then TARGET_CONF="$HYPR_USER_CONF"; fi
if [ -z "$TARGET_CONF" ] && [ -f "$HYPR_USER_ALT" ]; then TARGET_CONF="$HYPR_USER_ALT"; fi

mkdir -p "$HYPR_DIR"
if [ -z "$TARGET_CONF" ]; then
  TARGET_CONF="$HYPR_USER_CONF"
  touch "$TARGET_CONF"
fi

if ! grep -q 'exec-once *= *quickshell -c.*caelestia/shell.qml' "$TARGET_CONF"; then
  printf '\n# Autostart Caelestia (QuickShell)\nexec-once = quickshell -c ~/.config/quickshell/caelestia/shell.qml\n' >> "$TARGET_CONF"
  g "[v] Added exec-once to: $TARGET_CONF"
else
  g "[v] Autostart already present in: $TARGET_CONF"
fi

### ---- 8) quick sanity check (headless) ----
c "== Verifying QuickShell can find Caelestia types (headless dry-run) =="
# We intentionally avoid QT_QPA_PLATFORM=xcb at TTY, but we can at least confirm the config path exists.
if command -v quickshell >/dev/null 2>&1; then
  y "[i] If you’re on a black/triangle splash: press Super+Enter to open kitty, then run: caelestia-shell"
  y "[i] Inside a Wayland session (Hyprland), you can run directly: caelestia-shell"
else
  r "[x] quickshell not installed. Install via pacman (if available) or AUR (quickshell-bin/quickshell-git)."
  exit 1
fi

g "[v] All set."

cat <<TIP

To start Caelestia **now** (inside Hyprland/Wayland), run:
  caelestia-shell

Hyprland will also **autostart** Caelestia next login because we added:
  exec-once = quickshell -c ~/.config/quickshell/caelestia/shell.qml

If you only see the splash triangles, press:
  Super + Enter   (opens kitty)
then run:
  caelestia-shell

Log: $LOG
TIP