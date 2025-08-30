#!/usr/bin/env bash
# Caelestia full (re)install for Arch + Hyprland + QuickShell
# Uses:
#   - Shell UI: https://github.com/caelestia-dots/shell
#   - QML Modules: https://github.com/caelestia-dots/caelestia
#
# Safe to re-run. Logs saved to ~/.local/share/caelestia-install/installer.log

set -Eeuo pipefail

### ───────────────────────────── Config ─────────────────────────────
LOGDIR="$HOME/.local/share/caelestia-install"
LOGFILE="$LOGDIR/installer.log"

SHELL_DIR="$HOME/.config/quickshell/caelestia"              # active shell
MODULES_DIR="$SHELL_DIR/modules"                            # where we place Caelestia QML
LAUNCHER="$HOME/.local/bin/caelestia-shell"                 # command to launch
HYPRCONF="$HOME/.config/hypr/hyprland.conf"

REPO_SHELL="https://github.com/caelestia-dots/shell"
REPO_CAEL="https://github.com/caelestia-dots/caelestia"

### ─────────────────────────── Logging utils ────────────────────────
mkdir -p "$LOGDIR"
exec 3>>"$LOGFILE"
ts() { date +"%Y-%m-%d %H:%M:%S"; }
say()  { printf "\e[36m[+] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
ok()   { printf "\e[32m[✓] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
warn() { printf "\e[33m[!] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; }
die()  { printf "\e[31m[x] %s\e[0m %s\n" "$(ts)" "$*" | tee /dev/fd/3; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }
as_root() { command -v sudo >/dev/null 2>&1 || die "sudo not found. Install sudo & add your user to wheel."; sudo bash -c "$*"; }

### ───────────────────────── Network sanity ─────────────────────────
say "Checking internet…"
if ! ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
  warn "Ping to archlinux.org failed; continuing (mirrors might still work)."
else
  ok "Network OK."
fi

### ───────────────────── System packages (pacman) ───────────────────
say "Syncing pacman & installing base packages…"
as_root "pacman -Sy --noconfirm archlinux-keyring || true"
as_root "pacman -Syu --noconfirm"

# Core & graphics & Qt6
as_root "pacman -S --needed --noconfirm \
  git base-devel curl unzip rsync sed grep \
  mesa libva-mesa-driver vulkan-radeon \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland qt6-quickcontrols2 \
  hyprland kitty pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber"

ok "Core packages installed."

### ─────────────────── AUR helper (paru/yay) ────────────────────────
AUR=""
if need paru; then AUR="paru"
elif need yay; then AUR="yay"
else
  say "No AUR helper found; installing paru-bin (non-root build)…"
  WORK="$HOME/.cache/aur/paru-bin"
  rm -rf "$WORK"; mkdir -p "$WORK"
  git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$WORK" >&3
  ( cd "$WORK" && makepkg -si --noconfirm ) >&3
  AUR="paru"
fi
ok "AUR helper: $AUR"

### ───────────────────── QuickShell (AUR) ───────────────────────────
if ! need quickshell; then
  say "Installing QuickShell…"
  $AUR -S --noconfirm quickshell-bin || $AUR -S --noconfirm quickshell || die "Could not install quickshell."
else
  ok "QuickShell already present."
fi

### ───────────────────── Install Caelestia shell UI ─────────────────
say "Installing Caelestia shell (UI)…"
TMP_SHELL="$(mktemp -d)"
if [[ -d "$SHELL_DIR" ]]; then
  BAK="${SHELL_DIR}.bak.$(date +%s)"
  mv "$SHELL_DIR" "$BAK"
  ok "Backed up previous shell to $BAK"
fi
git -c advice.detachedHead=false clone --depth=1 "$REPO_SHELL" "$TMP_SHELL" >&3 || die "Failed to clone $REPO_SHELL"
mkdir -p "$SHELL_DIR"
rsync -a --delete "$TMP_SHELL"/ "$SHELL_DIR"/
rm -rf "$TMP_SHELL"
ok "Shell files installed to $SHELL_DIR"

### ───────────────────── Install Caelestia QML (modules) ────────────
say "Installing Caelestia QML modules…"
TMP_MOD="$(mktemp -d)"
git -c advice.detachedHead=false clone --depth=1 "$REPO_CAEL" "$TMP_MOD" >&3 || die "Failed to clone $REPO_CAEL"

# Try common layouts: use repo root by default (contains QML packages), falling back to subdirs
SRC_QML=""
for CAND in "$TMP_MOD/qml" "$TMP_MOD/modules" "$TMP_MOD/src" "$TMP_MOD"; do
  if find "$CAND" -maxdepth 1 -type d -iname "Caelestia"* | head -n1 >/dev/null 2>&1; then
    SRC_QML="$CAND"
    break
  fi
done
[[ -z "$SRC_QML" ]] && SRC_QML="$TMP_MOD"

rm -rf "$MODULES_DIR"
mkdir -p "$MODULES_DIR"
rsync -a "$SRC_QML"/ "$MODULES_DIR"/
rm -rf "$TMP_MOD"
ok "QML modules placed at $MODULES_DIR"

### ───────────────────── Launcher + env wiring ───────────────────────
say "Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="$HOME/.config/quickshell/caelestia"
# Build QML import path so QuickShell finds Caelestia types
declare -a PATHS=(
  "$CFG/modules"
  "$CFG/qml"
  "$CFG"
  "$HOME/.config/quickshell"
)
IMP=""
for p in "${PATHS[@]}"; do
  [[ -d "$p" ]] && IMP="${IMP:+$IMP:}$p"
done
export QML2_IMPORT_PATH="$IMP"
exec quickshell -c caelestia
EOF
chmod +x "$LAUNCHER"
ok "Launcher ready."

# Autostart inside Hyprland
mkdir -p "$(dirname "$HYPRCONF")"
touch "$HYPRCONF"
if ! grep -qE '^\s*exec-once\s*=\s*.*caelestia-shell' "$HYPRCONF"; then
  echo 'exec-once = caelestia-shell' >> "$HYPRCONF"
  ok "Added Hyprland autostart (exec-once = caelestia-shell)."
else
  ok "Hyprland autostart already present."
fi

### ────────────────────────── Final checks ───────────────────────────
echo
ok "Install finished. Log: $LOGFILE"
echo
if need hyprland; then
  echo "➤ If you are already in Hyprland: run   caelestia-shell"
  echo "➤ Otherwise: log in to Wayland/Hyprland; Caelestia will autostart."
else
  echo "➤ Start Hyprland (Wayland). After login, Caelestia autostarts."
fi

echo
say "Manual test command (inside Wayland session):"
echo "    quickshell -c caelestia"