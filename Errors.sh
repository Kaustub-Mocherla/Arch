#!/usr/bin/env bash
set -euo pipefail

say(){ printf "\033[1;36m[*]\033[0m %s\n" "$*"; }
ok(){  printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
warn(){printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

say "Installing required packages (Qt6, Wayland, GPU, PipeWire)…"
sudo pacman -S --needed --noconfirm \
  qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-svg qt6-imageformats \
  mesa pipewire wireplumber vulkan-radeon libva-mesa-driver git

say "Cloning Caelestia shell into ~/.config/quickshell/caelestia"
mkdir -p "$HOME/.config/quickshell"
if [[ -d "$HOME/.config/quickshell/caelestia/.git" ]]; then
  (cd "$HOME/.config/quickshell/caelestia" && git pull --rebase) || true
else
  git clone https://github.com/caelestia-dots/shell "$HOME/.config/quickshell/caelestia"
fi

say "Running Caelestia setup.sh"
chmod +x "$HOME/.config/quickshell/caelestia/setup.sh"
if ! "$HOME/.config/quickshell/caelestia/setup.sh"; then
  warn "setup.sh returned a non-zero status. Continuing; check its messages above."
fi

say "Ensuring Hyprland autostarts Caelestia"
mkdir -p "$HOME/.config/hypr"
CONF="$HOME/.config/hypr/hyprland.conf"
if ! grep -q 'exec = quickshell -c caelestia' "$CONF" 2>/dev/null; then
  {
    echo ""
    echo "# Autostart Caelestia QuickShell"
    echo "exec = quickshell -c caelestia"
  } >> "$CONF"
fi
ok "Done. Log into Hyprland and you should see Caelestia."
ok "Manual launch inside Hyprland: quickshell -c caelestia"