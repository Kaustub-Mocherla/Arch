#!/usr/bin/env bash
# Caelestia: full reset + install (shell UI from caelestia-dots/shell)
# Safe to re-run. Tries hard, logs everything, and won’t break your user config outside Caelestia.

set -euo pipefail

# ----------------------------- Config ---------------------------------
CAEL_REPO="https://github.com/caelestia-dots/caelestia"
SHELL_REPO="https://github.com/caelestia-dots/shell"
LOGFILE="${HOME}/caelestia_one_shot.log"
QS_DESKTOP_ENTRY="/usr/share/applications/quickshell.desktop" # signal QuickShell install
HYPR_CONF_DIR="${HOME}/.config/hypr"
HYPR_CONF="${HYPR_CONF_DIR}/hyprland.conf"
QS_CONF_DIR="${HOME}/.config/quickshell/caelestia"
TMPDIR="$(mktemp -d -t caelestia-XXXXXXXX)"
# ----------------------------------------------------------------------

note(){ printf "\033[1;36m[i]\033[0m %s\n" "$*"; }
ok(){   printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err(){  printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

cleanup(){
  rm -rf "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT

log_exec(){ echo -e "\n>> $*\n" | tee -a "$LOGFILE"; "$@" 2>&1 | tee -a "$LOGFILE"; }

sudo_advise(){
  echo
  warn "Some steps need packages. When asked for a password, enter your USER password (sudo)."
  echo
}

require_net(){
  if ! ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    warn "No reliable network reply (archlinux.org). We'll continue, but if downloads fail, fix your network and re-run."
  else
    ok "Internet reachable."
  fi
}

# ----------------------- Package install helpers ----------------------
pacman_try(){
  if have pacman; then
    sudo -v || true
    sudo pacman -Sy --needed --noconfirm "$@" || return 1
    return 0
  fi
  return 1
}

aur_try(){
  # Try yay then paru
  if have yay; then yay -S --needed --noconfirm "$@" && return 0; fi
  if have paru; then paru -S --needed --noconfirm "$@" && return 0; fi
  return 1
}

build_quickshell_from_source(){
  note "Building QuickShell from source (last resort)…"
  local qsdir="${TMPDIR}/quickshell"
  git clone --depth=1 https://github.com/Quickshell/Quickshell.git "$qsdir" | tee -a "$LOGFILE"
  pushd "$qsdir" >/dev/null
  note "Installing build deps…"
  pacman_try base-devel cmake ninja gcc || true
  pacman_try qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-svg || true
  note "Configuring & building…"
  log_exec cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
  log_exec cmake --build build
  note "Installing QuickShell (needs sudo)…"
  log_exec sudo cmake --install build
  popd >/dev/null
}

ensure_quickshell(){
  if have quickshell || [ -f "$QS_DESKTOP_ENTRY" ]; then
    ok "QuickShell already present."
    return
  fi
  sudo_advise
  note "Installing QuickShell via pacman (if available)…"
  if pacman_try quickshell; then ok "QuickShell installed (pacman)."; return; fi
  note "Installing QuickShell via AUR helper (yay/paru)…"
  if aur_try quickshell quickshell-bin quickshell-git; then ok "QuickShell installed (AUR)."; return; fi
  build_quickshell_from_source
  if have quickshell; then ok "QuickShell installed (source)."; else err "QuickShell install failed." ; exit 1; fi
}

ensure_runtime_deps(){
  sudo_advise
  note "Installing Qt/Wayland runtime & tools (safe to skip if already present)…"
  # many were “skipping” on your machine; that’s fine
  pacman_try \
    git curl unzip tar \
    qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-svg \
    pipewire wireplumber kitty hyprland || true
}

# -------------------------- Git/Zip fetch -----------------------------
grab_repo(){
  # $1 repo url, $2 dest dir
  local repo="$1" dest="$2"
  local name="$(basename "$repo")"
  mkdir -p "$(dirname "$dest")"
  if have git; then
    note "Cloning $name (git)…"
    if ! GIT_ASKPASS=echo git clone --depth=1 "$repo" "$dest" 2>>"$LOGFILE"; then
      warn "git clone failed. Falling back to zip download."
    else
      ok "Cloned $name."
      return 0
    fi
  fi
  # zip fallback
  local zipurl="${repo%/}.zip"
  local zipfile="${TMPDIR}/${name}.zip"
  note "Downloading $name as zip…"
  curl -L --fail "$zipurl" -o "$zipfile" 2>>"$LOGFILE" || { err "curl failed for $zipurl"; return 1; }
  mkdir -p "$dest"
  note "Unpacking $name…"
  unzip -q "$zipfile" -d "$TMPDIR/unzip" || { err "unzip failed for $name"; return 1; }
  # Move contents regardless of top-dir name
  shopt -s dotglob nullglob
  local topdir; topdir="$(find "$TMPDIR/unzip" -maxdepth 1 -type d ! -path "$TMPDIR/unzip" | head -n1)"
  if [ -z "${topdir:-}" ]; then err "Zip structure unexpected for $name"; return 1; fi
  mv "$topdir"/* "$dest"/
  ok "Unpacked $name."
  return 0
}

# ----------------------- Wire Caelestia files -------------------------
wire_shell(){
  note "Resetting Caelestia QuickShell config…"
  rm -rf "$QS_CONF_DIR"
  mkdir -p "$QS_CONF_DIR"

  local caeldir="${TMPDIR}/caelestia-main"
  local shelldir="${TMPDIR}/caelestia-shell"

  grab_repo "$CAEL_REPO" "$caeldir" || { err "Failed to get main caelestia repo."; exit 1; }
  grab_repo "$SHELL_REPO" "$shelldir" || { err "Failed to get caelestia shell repo."; exit 1; }

  note "Copying Caelestia modules…"
  if [ ! -d "$caeldir/modules" ]; then
    err "Main repo does not contain 'modules/'. Check the repo contents."
    exit 1
  fi
  cp -r "$caeldir/modules" "$QS_CONF_DIR/"

  note "Copying shell UI files…"
  # shell repo has its own structure; we copy its content into the Caelestia config
  cp -r "$shelldir/"* "$QS_CONF_DIR/"

  # sanity
  if [ ! -f "$QS_CONF_DIR/shell.qml" ]; then
    err "shell.qml not found after copy. The shell repo layout might have changed."
    exit 1
  fi
  if [ ! -d "$QS_CONF_DIR/modules" ]; then
    err "modules folder missing after copy. Aborting."
    exit 1
  fi
  ok "Caelestia files wired."
}

autostart_hyprland(){
  mkdir -p "$HYPR_CONF_DIR"
  touch "$HYPR_CONF"
  if ! grep -q 'exec-once\s*=\s*quickshell\s*-c\s*caelestia' "$HYPR_CONF"; then
    note "Adding Caelestia autostart to Hyprland…"
    printf '\n# Autostart Caelestia Shell\nexec-once = quickshell -c caelestia\n' >> "$HYPR_CONF"
  else
    ok "Hyprland autostart already present."
  fi
}

# ----------------------------- Run ------------------------------------
echo -e "\n==> Caelestia full RESET + INSTALL started ==" | tee "$LOGFILE"
require_net
ensure_runtime_deps
ensure_quickshell
wire_shell
autostart_hyprland

# Quick self-check
echo >> "$LOGFILE"
note "Self-checking file presence…"
[ -f "$QS_CONF_DIR/shell.qml" ] && ok "shell.qml present." || err "shell.qml missing!"
[ -d "$QS_CONF_DIR/modules" ] && ok "modules/ present." || err "modules missing!"

cat <<EOF

────────────────────────────────────────────────────────────────
All set.

• In Hyprland, Caelestia should auto-start next login (we added exec-once).
• You can also launch manually (inside Wayland/Hyprland):

    env QT_QPA_PLATFORM=wayland quickshell -c caelestia
      — or simply —
    quickshell -c caelestia

• If you still see only the triangle splash, open a terminal (Super+Enter if kitty)
  and run the manual command above to see live errors (also logged).

Log file: $LOGFILE
Config:   $QS_CONF_DIR
Hypr conf: $HYPR_CONF
────────────────────────────────────────────────────────────────
EOF

ok "Done."