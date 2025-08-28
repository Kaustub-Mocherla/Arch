#!/usr/bin/env bash
# install_caelestia.sh — bulletproof Caelestia setup for Arch + Hyprland
set -Eeuo pipefail

LOG="$HOME/caelestia_install.log"
exec > >(tee -a "$LOG") 2>&1

say()   { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
die()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" ; exit 1; }

need()  { command -v "$1" >/dev/null 2>&1 || return 1; }

# --- 0) Network sanity --------------------------------------------------------
say "Checking internet..."
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "No internet. Connect and re-run."

# --- 1) System deps -----------------------------------------------------------
say "Installing system dependencies… (you may be asked for sudo password)"
sudo pacman -Syy --noconfirm
sudo pacman -S --noconfirm --needed \
  git curl ca-certificates unzip tar file \
  qt6-base qt6-declarative qt6-svg qt6-shadertools qt6-wayland \
  hyprland kitty pipewire wireplumber

# QuickShell (repo or AUR fallback)
if ! need quickshell; then
  say "Installing QuickShell…"
  if ! sudo pacman -S --noconfirm quickshell; then
    warn "quickshell not in repo; falling back to AUR."
    sudo pacman -S --noconfirm --needed base-devel
    tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/quickshell-git.git "$tmp/quickshell-git"
    (cd "$tmp/quickshell-git" && makepkg -si --noconfirm)
  fi
fi
need quickshell || die "QuickShell install failed."

# --- 2) Fetch helper (clone first, then tar fallback with verification) -------
fetch_into() {
  # $1 = git_url  $2 = tar_url  $3 = target_dir
  local git_url="$1" tar_url="$2" dest="$3"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  # Avoid interactive git prompts
  export GIT_ASKPASS=/bin/true
  export GIT_TERMINAL_PROMPT=0

  say "Cloning $(basename "$dest") via git…"
  if git clone --depth=1 "$git_url" "$dest" 2>/tmp/cael_git.err; then
    ok "Cloned $(basename "$dest")."
    return 0
  fi

  warn "git clone failed; trying tarball…"
  local tmp="$(mktemp)"
  if ! curl -L --fail --retry 3 --connect-timeout 10 -o "$tmp" "$tar_url"; then
    warn "curl download failed for $(basename "$dest")."
  else
    # Verify it really is gzip (not HTML)
    if [ "$(file -b --mime-type "$tmp")" = "application/gzip" ]; then
      mkdir -p "$dest"
      # strip top-level folder
      tar -xz -C "$dest" --strip-components=1 -f "$tmp"
      rm -f "$tmp"
      ok "Extracted $(basename "$dest") from tarball."
      return 0
    else
      warn "Downloaded file was not a gzip tarball (probable HTML/rate-limit)."
      rm -f "$tmp"
    fi
  fi
  return 1
}

# --- 3) Fetch Caelestia shell + modules --------------------------------------
CELE_DIR="$HOME/.config/quickshell/caelestia"
MOD_DIR="$CELE_DIR/modules"

say "Fetching Caelestia Shell…"
fetch_into \
  "https://github.com/caelestia-dots/shell.git" \
  "https://github.com/caelestia-dots/shell/archive/refs/heads/main.tar.gz" \
  "$CELE_DIR" \
  || die "Failed to fetch Caelestia Shell."

say "Fetching Caelestia Modules…"
fetch_into \
  "https://github.com/caelestia-dots/modules.git" \
  "https://github.com/caelestia-dots/modules/archive/refs/heads/main.tar.gz" \
  "$MOD_DIR" \
  || die "Failed to fetch Caelestia Modules."

# --- 4) Autostart in Hyprland -------------------------------------------------
HYPR_DIR="$HOME/.config/hypr"
HYPR_USER_CONF="$HYPR_DIR/hypr-user.conf"
mkdir -p "$HYPR_DIR"
touch "$HYPR_USER_CONF"
# remove duplicates then append
sed -i '/quickshell -c caelestia/d' "$HYPR_USER_CONF" || true
echo 'exec-once = quickshell -c caelestia' >> "$HYPR_USER_CONF"
ok "Autostart added to $HYPR_USER_CONF"

# --- 5) Handy launcher in ~/.local/bin ---------------------------------------
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'EOF'
#!/usr/bin/env bash
exec quickshell -c caelestia
EOF
chmod +x "$HOME/.local/bin/caelestia-shell"
ok "Command installed: caelestia-shell"

# --- 6) Smoke test (syntax load check; won’t start XCB at TTY) ----------------
say "Quick syntax check (will not show UI on TTY)…"
if quickshell -c "$CELE_DIR/shell.qml" --syntax 2>/dev/null; then
  ok "QML syntax OK."
else
  warn "QML syntax check reported issues — you can still try starting inside Hyprland."
fi

echo
ok "Caelestia installed."
echo "• Log: $LOG"
echo "• To start now (inside Hyprland):  quickshell -c caelestia"
echo "• Re-login to Hyprland and Caelestia should autostart."