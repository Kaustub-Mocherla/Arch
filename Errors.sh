cat > ~/build_quickshell_safe.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/quickshell_build.log"
echo -e "\n== QuickShell safe build == $(date)\n" | tee -a "$LOG"

# ---------- Helpers ----------
say(){ echo -e "[*] $*" | tee -a "$LOG"; }
ok(){  echo -e "[✓] $*" | tee -a "$LOG"; }
warn(){ echo -e "[!] $*" | tee -a "$LOG"; }
die(){ echo -e "[x] $*" | tee -a "$LOG"; exit 1; }

# ---------- Power / thermal sanity ----------
if [ -e /sys/class/power_supply/AC/online ]; then
  AC=$(cat /sys/class/power_supply/AC/online)
elif [ -e /sys/class/power_supply/ACAD/online ]; then
  AC=$(cat /sys/class/power_supply/ACAD/online)
else
  AC=1
fi
[ "$AC" = "1" ] || warn "You appear to be on BATTERY. Please plug in AC power."

# ---------- Swap (helps prevent sudden power-offs due to OOM) ----------
HAS_SWAP=$(swapon --noheadings || true)
if [ -z "$HAS_SWAP" ]; then
  say "No swap detected. Creating a 2G swapfile (one-time)…"
  sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  if ! grep -q '^/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  fi
  ok "Swap enabled."
else
  ok "Swap already present."
fi

# ---------- Packages we need (minimal) ----------
say "Installing build dependencies (low-load)…"
sudo pacman -Syu --needed --noconfirm \
  base-devel git cmake ninja \
  qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools curl

ok "Deps in place."

# ---------- Environment: build slow and nice ----------
export MAKEFLAGS="-j1"
export NINJAFLAGS="-j1"
export CMAKE_BUILD_PARALLEL_LEVEL=1

# ---------- Fetch QuickShell (correct upstream or GitHub mirror) ----------
SRC="$HOME/quickshell-src"
say "Fetching QuickShell source…"
rm -rf "$SRC"
# Prefer the official upstream:
if curl -fsSL -o /dev/null https://git.outfoxxed.me/quickshell/quickshell.git; then
  git clone https://git.outfoxxed.me/quickshell/quickshell.git "$SRC" | tee -a "$LOG"
else
  # Fallback to GitHub mirror
  git clone https://github.com/quickshell-mirror/quickshell.git "$SRC" | tee -a "$LOG"
fi
ok "Source ready."

# ---------- Configure & build ----------
cd "$SRC"
say "Configuring (CMake)…"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release . | tee -a "$LOG"

say "Building (slow mode: -j1, nice/ionice)… this can take a while."
nice -n 19 ionice -c3 cmake --build build | tee -a "$LOG"

# ---------- Install ----------
say "Installing QuickShell…"
sudo cmake --install build | tee -a "$LOG"
ok "QuickShell installed."

# ---------- Verify ----------
say "Verifying quickshell runs (won't start UI, just check binary)…"
if command -v quickshell >/dev/null; then
  quickshell --help >/dev/null 2>&1 || true
  ok "quickshell binary found."
else
  die "quickshell not on PATH after install."
fi

echo
ok "All done. Next steps:
  1) Ensure Caelestia shell files exist under: ~/.config/quickshell/caelestia/shell.qml
  2) Launch *inside Hyprland/Wayland*:   caelestia-shell
  3) If 'module Caelestia is not installed', run your setup script again (it populates ~/.config/quickshell/caelestia/modules)."
EOF

chmod +x ~/build_quickshell_safe.sh