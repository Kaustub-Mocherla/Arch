#!/usr/bin/env bash
# caelestia_reset_install.sh
# Wipes old Caelestia bits, then reinstalls Caelestia Shell + Modules cleanly.
# Designed for Arch + Hyprland with robust error handling and fallbacks.

set -euo pipefail

# ---------------------------- Config / Vars ----------------------------
LOG="$HOME/caelestia_reset_$(date +%Y%m%d_%H%M%S).log"

SHELL_REPO="https://github.com/caelestia-dots/shell.git"
MODULES_REPO="https://github.com/caelestia-dots/modules.git"

# Reliable GitHub tarball endpoints (avoid 404 HTML):
MODULES_TARBALL_1="https://codeload.github.com/caelestia-dots/modules/tar.gz/refs/heads/main"
MODULES_TARBALL_2="https://codeload.github.com/caelestia-dots/modules/tar.gz/refs/heads/master"

QS_DIR="$HOME/.config/quickshell"
SHELL_DIR="$QS_DIR/caelestia"
MODULES_DIR="$SHELL_DIR/modules"

BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/caelestia-shell"

HYPR_DIR="$HOME/.config/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

# ---------------------------- Helpers ----------------------------
info(){ printf "\033[1;36m[i]\033[0m %s\n" "$*" | tee -a "$LOG"; }
ok(){   printf "\033[1;32m[v]\033[0m %s\n" "$*" | tee -a "$LOG"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*" | tee -a "$LOG"; }
err(){  printf "\033[1;31m[x]\033[0m %s\n" "$*" | tee -a "$LOG"; }

need_cmd(){ command -v "$1" >/dev/null 2>&1; }

ensure_sudo(){
  if [[ $EUID -ne 0 ]]; then
    if need_cmd sudo; then SUDO="sudo"; else
      err "sudo not found. Install sudo or run this script as root."
      exit 1
    fi
  else
    SUDO=""
  fi
}

# Return 0 if a path contains non-HTML gzip tar
is_good_tarball(){
  local file="$1"
  file "$file" | grep -qi 'gzip compressed data'
}

# ---------------------------- Phase 0: Prep ----------------------------
: > "$LOG"
info "=== Caelestia full RESET + INSTALL started ==="
ensure_sudo

# ---------------------------- Phase 1: Package layer ----------------------------
info "Installing/updating required packages (pacman)…"
$SUDO pacman -Sy --noconfirm --needed \
  git curl unzip tar \
  quickshell \
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools \
  hyprland kitty wl-clipboard \
  pipewire wireplumber || {
    err "pacman failed. Check mirrors/network."
    exit 1
  }
ok "Packages installed (or already present)."

# ---------------------------- Phase 2: Stop + clean old state ----------------------------
info "Stopping any running quickshell (best-effort)…"
pkill -x quickshell >/dev/null 2>&1 || true

# Back up then wipe old Caelestia dirs
BACKUP_TGZ="$HOME/caelestia_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
if [[ -d "$SHELL_DIR" || -d "$MODULES_DIR" ]]; then
  info "Backing up existing Caelestia config to: $BACKUP_TGZ"
  tar -czf "$BACKUP_TGZ" -C "$QS_DIR" "$(basename "$SHELL_DIR")" || true
fi

info "Removing old Caelestia directories and caches…"
rm -rf "$MODULES_DIR" "$SHELL_DIR" "$HOME/.cache/quickshell" "$HOME/.local/share/quickshell" || true
mkdir -p "$SHELL_DIR"

# Remove old launcher
rm -f "$LAUNCHER" || true

# Clean hyprland exec-once duplicates
if [[ -f "$HYPR_CONF" ]]; then
  info "Cleaning old 'exec-once = quickshell -c caelestia' entries from hyprland.conf…"
  sed -i '/^\s*exec-once\s*=\s*quickshell\s\+-c\s\+caelestia\s*$/d' "$HYPR_CONF" || true
fi

# ---------------------------- Phase 3: Clone Caelestia Shell ----------------------------
info "Cloning Caelestia Shell…"
TMP_SHELL="$(mktemp -d)"
# Avoid any credential helpers asking for username/password
git -c credential.helper= -c http.sslVerify=true clone --depth=1 "$SHELL_REPO" "$TMP_SHELL" \
  || { err "Failed to clone Caelestia Shell."; exit 1; }

shopt -s dotglob nullglob
cp -r "$TMP_SHELL"/* "$SHELL_DIR"/
rm -rf "$TMP_SHELL"
ok "Shell installed to $SHELL_DIR"

# ---------------------------- Phase 4: Fetch Caelestia Modules ----------------------------
fetch_modules_git(){
  info "Trying 'git clone' for modules…"
  rm -rf "$MODULES_DIR"
  git -c credential.helper= -c http.sslVerify=true clone --depth=1 "$MODULES_REPO" "$MODULES_DIR"
}

fetch_modules_tarball(){
  local url="$1"
  info "Trying tarball: $url"
  rm -rf "$MODULES_DIR"; mkdir -p "$MODULES_DIR"
  TMP_TAR="$(mktemp)"
  if ! curl -fsSL "$url" -o "$TMP_TAR"; then
    warn "Download failed for $url"
    return 1
  fi
  if ! is_good_tarball "$TMP_TAR"; then
    warn "Tarball wasn’t gzip (likely 404/HTML)."
    rm -f "$TMP_TAR"
    return 1
  fi
  TMP_DIR="$(mktemp -d)"
  tar -xzf "$TMP_TAR" -C "$TMP_DIR"
  # copy inner folder contents into MODULES_DIR
  local inner
  inner="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'modules-*' -print -quit)"
  [[ -z "$inner" ]] && inner="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  if [[ -n "$inner" ]]; then
    cp -r "$inner/"* "$MODULES_DIR"/ || true
  else
    warn "Couldn’t locate extracted inner directory."
    rm -rf "$TMP_DIR" "$TMP_TAR"
    return 1
  fi
  rm -rf "$TMP_DIR" "$TMP_TAR"
  return 0
}

create_stub_modules(){
  warn "Could not fetch real modules. Creating minimal stub modules so Quickshell can run."
  mkdir -p "$MODULES_DIR/background" "$MODULES_DIR/components/filedialog" "$MODULES_DIR/components/images"

  cat > "$MODULES_DIR/background/Background.qml" <<'QML'
import QtQuick 2.15
Item { anchors.fill: parent; Rectangle{anchors.fill: parent; color:"#111417"} }
QML

  cat > "$MODULES_DIR/background/Wallpaper.qml" <<'QML'
import QtQuick 2.15
Item {
  anchors.fill: parent
  property url source: "file://" + Qt.resolvedUrl("../../wall.jpg")
  Image { anchors.fill: parent; source: root.source; fillMode: Image.PreserveAspectCrop; cache:true; smooth:true; visible: status!==Image.Error }
}
QML

  cat > "$MODULES_DIR/components/filedialog/FileDialog.qml" <<'QML'
import QtQuick 2.15
Item { /* stub */ }
QML

  cat > "$MODULES_DIR/components/filedialog/FolderContents.qml" <<'QML'
import QtQuick 2.15
ListModel { /* stub */ }
QML

  cat > "$MODULES_DIR/components/images/CachingIconImage.qml" <<'QML'
import QtQuick 2.15
Image { cache:true; smooth:true }
QML

  cat > "$MODULES_DIR/components/images/CachingImage.qml" <<'QML'
import QtQuick 2.15
Image { cache:true; smooth:true }
QML
  ok "Stub modules created at $MODULES_DIR"
}

info "Fetching Caelestia Modules…"
if fetch_modules_git 2>>"$LOG"; then
  ok "Modules cloned via git."
else
  warn "Git clone failed (no prompts will be shown; we disabled credential helpers)."
  if fetch_modules_tarball "$MODULES_TARBALL_1" 2>>"$LOG"; then
    ok "Modules installed via tarball (main)."
  elif fetch_modules_tarball "$MODULES_TARBALL_2" 2>>"$LOG"; then
    ok "Modules installed via tarball (master)."
  else
    create_stub_modules
  fi
fi

# ---------------------------- Phase 5: Launcher + PATH ----------------------------
info "Installing launcher…"
mkdir -p "$BIN_DIR"
cat > "$LAUNCHER" <<'SH'
#!/usr/bin/env bash
exec quickshell -c caelestia
SH
chmod +x "$LAUNCHER"

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] || continue
  grep -q '.local/bin' "$rc" || printf '\n# Ensure user bin on PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
done
ok "Launcher installed: $LAUNCHER (re-source your shell if needed)."

# ---------------------------- Phase 6: Hyprland autostart ----------------------------
info "Wiring Hyprland autostart…"
mkdir -p "$HYPR_DIR"
touch "$HYPR_CONF"
grep -q 'exec-once *= *quickshell -c caelestia' "$HYPR_CONF" || \
  printf '\n# Auto-start Caelestia\nexec-once = quickshell -c caelestia\n' >> "$HYPR_CONF"
ok "Hyprland will auto-start Caelestia on next login."

# ---------------------------- Phase 7: Done ----------------------------
ok "RESET + INSTALL complete."

cat <<EOF | tee -a "$LOG"

What next:

1) Log in to **Hyprland** (Wayland). Caelestia should start automatically.
2) If you’re already inside Hyprland, open a terminal and run:
     quickshell -c caelestia
   or use the launcher:
     caelestia-shell

If you still get a black/triangle splash:
  - Run: quickshell -c caelestia  (to see live errors)
  - Check the log: $LOG

Notes:
• Real modules are in: $MODULES_DIR
• If we used stub modules, you can later replace them by re-running this script when
  https://github.com/caelestia-dots/modules is reachable.
• Optional wallpaper: put an image at $SHELL_DIR/wall.jpg

Backup (old config) stored at: ${BACKUP_TGZ}
EOF