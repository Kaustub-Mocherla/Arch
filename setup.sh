#!/usr/bin/env bash
# Caelestia: full (re)install + autostart, with graceful fallback when "modules" repo is missing.
# Safe to re-run. Logs to ~/.local/share/caelestia-install/installer.log

set -Eeuo pipefail

### ────────────────────────────── config ──────────────────────────────
LOGDIR="$HOME/.local/share/caelestia-install"
LOGFILE="$LOGDIR/installer.log"
SHELL_DIR="$HOME/.config/quickshell/caelestia"
CANDIDATE_MODULE_DIRS=("$SHELL_DIR/modules" "$SHELL_DIR/qml" "$SHELL_DIR/Modules" "$SHELL_DIR/src/modules")
LAUNCHER="$HOME/.local/bin/caelestia-shell"

# Official repos
REPO_SHELL="https://github.com/caelestia-dots/shell"
# The old modules repo has gone private/removed for many users; leave as null/placeholder
REPO_MODULES_GIT="https://github.com/caelestia-dots/modules"
REPO_MODULES_TARBALL="https://codeload.github.com/caelestia-dots/modules/tar.gz/refs/heads/main"

### ─────────────────────────── helpers/logging ────────────────────────
mkdir -p "$LOGDIR"
exec 3>>"$LOGFILE"
ts() { date +"%Y-%m-%d %H:%M:%S"; }
say() { printf "\e[36m[+] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
ok()  { printf "\e[32m[✓] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
warn(){ printf "\e[33m[!] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
die() { printf "\e[31m[x] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; exit 1; }

need() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if need sudo; then sudo bash -c "$*"
  else die "sudo not found. Install sudo and add your user to wheel."
  fi
}

http_ok() {
  local url="$1"
  curl -fsLI --retry 3 --retry-delay 1 "$url" >/dev/null 2>&1
}

### ───────────────────────── network sanity ───────────────────────────
say "Checking internet…"
if ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
  ok "Network looks good."
else
  warn "Ping to archlinux.org failed; continuing anyway (mirrors may still work)."
fi

### ───────────────────── system packages (pacman) ─────────────────────
say "Syncing pacman and installing base packages…"
as_root "pacman -Sy --noconfirm archlinux-keyring || true"
as_root "pacman -Syu --noconfirm"
as_root "pacman -S --needed --noconfirm \
  git base-devel curl unzip rsync sed grep \
  mesa libva-mesa-driver vulkan-radeon \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
  hyprland kitty pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber"

ok "Core packages present."

### ───────────────────── AUR helper (paru or yay) ─────────────────────
AUR_HELPER=""
if need paru; then AUR_HELPER="paru"
elif need yay; then AUR_HELPER="yay"
else
  say "No AUR helper found; installing paru-bin (non-root build)…"
  WORK="$HOME/.cache/aur/paru-bin"
  rm -rf "$WORK"; mkdir -p "$WORK"
  git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$WORK" >&3
  ( cd "$WORK" && makepkg -si --noconfirm ) >&3
  AUR_HELPER="paru"
fi
ok "AUR helper: $AUR_HELPER"

### ─────────────────── QuickShell (from AUR) ─────────────────────────
if ! need quickshell; then
  say "Installing QuickShell from AUR…"
  $AUR_HELPER -S --noconfirm quickshell-bin || $AUR_HELPER -S --noconfirm quickshell || die "Could not install quickshell."
else
  ok "QuickShell already present."
fi

### ───────────────────── Caelestia shell (config) ─────────────────────
say "Resetting Caelestia shell config…"
if [[ -d "$SHELL_DIR" ]]; then
  BAK="${SHELL_DIR}.bak.$(date +%s)"
  mv "$SHELL_DIR" "$BAK"
  ok "Backed up old shell to $BAK"
fi
mkdir -p "$SHELL_DIR"

say "Fetching Caelestia shell repo…"
TMP_SHELL="$(mktemp -d)"
git -c advice.detachedHead=false clone --depth=1 "$REPO_SHELL" "$TMP_SHELL" >&3 || die "Failed to clone $REPO_SHELL"

# Prefer a top-level shell.qml; otherwise copy all and hope layout matches upstream
if [[ -f "$TMP_SHELL/shell.qml" ]]; then
  rsync -a --delete "$TMP_SHELL"/ "$SHELL_DIR"/
else
  rsync -a --delete "$TMP_SHELL"/ "$SHELL_DIR"/
fi
ok "Installed shell to $SHELL_DIR"
rm -rf "$TMP_SHELL"

### ───────────────────── Caelestia modules (QML) ──────────────────────
have_modules=0

# 1) If the shell repo already contains a "modules" or "qml" dir with Caelestia types, use it.
for d in "${CANDIDATE_MODULE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    have_modules=1
    ok "Found modules in: $d"
    break
  fi
done

# 2) Try to clone a public modules repo if it exists
if [[ $have_modules -eq 0 ]]; then
  if http_ok "$REPO_MODULES_GIT"; then
    say "Attempting to clone Caelestia modules… (public repo detected)"
    MODDIR="$SHELL_DIR/modules"
    git clone --depth=1 "$REPO_MODULES_GIT" "$MODDIR" >&3 || true
    if [[ -d "$MODDIR" ]]; then
      have_modules=1
      ok "Cloned modules to $MODDIR"
    fi
  else
    warn "Modules git repo not reachable (likely private or removed)."
  fi
fi

# 3) Try codeload tarball (if it exists)
if [[ $have_modules -eq 0 && $(http_ok "$REPO_MODULES_TARBALL"; echo $?) -eq 0 ]]; then
  say "Downloading modules tarball…"
  MODDIR="$SHELL_DIR/modules"
  TMP_TAR="$(mktemp)"
  curl -fsSL "$REPO_MODULES_TARBALL" -o "$TMP_TAR" || true
  mkdir -p "$MODDIR"
  # Unpack (guard for non-gzip)
  if tar -tzf "$TMP_TAR" >/dev/null 2>&1; then
    tar -xzf "$TMP_TAR" -C "$MODDIR" --strip-components=1
    have_modules=1
    ok "Extracted modules tarball to $MODDIR"
  else
    warn "Downloaded file is not a valid gzip tarball (likely 404 HTML)."
  fi
  rm -f "$TMP_TAR"
fi

# 4) If still missing, create the directory and instruct user to drop modules later.
if [[ $have_modules -eq 0 ]]; then
  MODDIR="$SHELL_DIR/modules"
  mkdir -p "$MODDIR"
  warn "Caelestia modules are still missing. The shell **will not start** until they exist."
  warn "→ Put the modules QML here: $MODDIR"
  warn "   (If you get a ZIP/folder later, just extract/copy it into that path and re-run: quickshell -c caelestia)"
fi

### ─────────────────────── launcher + autostart ───────────────────────
say "Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="$HOME/.config/quickshell/caelestia"
declare -a PATHS=(
  "$CFG/modules"
  "$CFG/qml"
  "$CFG"
)
# Compose QML2_IMPORT_PATH with existing dirs
IMP=""
for p in "${PATHS[@]}"; do
  [[ -d "$p" ]] && IMP="${IMP:+$IMP:}$p"
done
export QML2_IMPORT_PATH="$IMP"
exec quickshell -c caelestia
EOF
chmod +x "$LAUNCHER"
ok "Launcher ready."

# Hyprland autostart (append if not present)
HYPRD="$HOME/.config/hypr/hyprland.conf"
mkdir -p "$(dirname "$HYPRD")"
touch "$HYPRD"
if ! grep -q 'exec-once\s*=.*caelestia-shell' "$HYPRD"; then
  echo 'exec-once = caelestia-shell' >> "$HYPRD"
  ok "Added Hyprland autostart (exec-once = caelestia-shell)"
else
  ok "Hyprland autostart already present."
fi

### ─────────────────────────── final message ──────────────────────────
echo
ok "Setup complete."
echo "Log file: $LOGFILE"
echo
if [[ $have_modules -eq 0 ]]; then
  warn "Modules missing. Until you drop the modules QML into:"
  echo "      $SHELL_DIR/modules"
  echo "the shell will show 'module Caelestia is not installed' errors."
  echo
  echo "When you obtain them (e.g., someone gives you a ZIP):"
  echo "  1) Extract into $SHELL_DIR/modules"
  echo "  2) Run:    quickshell -c caelestia"
  echo "  3) Or re-login to Hyprland"
else
  ok "You can now start it inside Wayland/Hyprland:"
  echo "    quickshell -c caelestia"
  echo "Or just re-login; Hyprland will autostart it."
fi