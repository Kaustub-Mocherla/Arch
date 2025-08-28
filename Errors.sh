cat > ~/repair_caelestia.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[i] Installing required packages…"
sudo pacman -S --needed \
  quickshell qt6-wayland qt6-declarative qt6-quickcontrols2 qt6-svg \
  hyprland swww kitty git base-devel

# Ensure Caelestia shell files exist
mkdir -p "$HOME/.config/quickshell"
if [ ! -d "$HOME/.config/quickshell/caelestia" ]; then
  echo "[i] Fetching Caelestia shell…"
  git clone --depth=1 https://github.com/caelestia-dots/shell "$HOME/.config/quickshell/caelestia"
else
  echo "[i] Caelestia shell already present; pulling updates…"
  git -C "$HOME/.config/quickshell/caelestia" pull --ff-only || true
fi

# Basic sanity
if ! command -v qs >/dev/null; then
  echo "[x] 'qs' (Quickshell) not in PATH. Aborting." >&2
  exit 1
fi
if [ ! -f "$HOME/.config/quickshell/caelestia/shell.qml" ]; then
  echo "[x] shell.qml missing in ~/.config/quickshell/caelestia. Aborting." >&2
  exit 1
fi

# Hyprland autostart
CFG="$HOME/.config/hypr/hyprland.conf"
mkdir -p "$(dirname "$CFG")"

# Remove any previous duplicate lines
tmpcfg="$(mktemp)"
if [ -f "$CFG" ]; then
  sed '/# BEGIN Caelestia Autostart/,/# END Caelestia Autostart/d' "$CFG" > "$tmpcfg"
else
  : > "$tmpcfg"
fi

{
  echo ''
  echo '# BEGIN Caelestia Autostart (managed)'
  echo 'exec-once = qs -c ~/.config/quickshell/caelestia/shell.qml'
  # Safety terminal on first boot so you’re never “stuck” on a blank screen.
  # You can comment this line later if you don’t want a terminal to appear:
  echo 'exec-once = kitty'
  # Optional wallpaper daemon (uncomment and set your image if you want)
  # echo 'exec-once = swww init && swww img ~/.config/quickshell/caelestia/assets/wallpapers/default.jpg'
  echo '# END Caelestia Autostart'
} >> "$tmpcfg"

mv "$tmpcfg" "$CFG"

echo
echo "[✓] Autostart written to $CFG"
echo "[i] To stop auto-launching a terminal, delete the 'exec-once = kitty' line later."
echo
echo "[→] Now reboot, log into **Hyprland**, and Caelestia should appear."
echo "    From a terminal inside Hyprland you can test manually:"
echo "       qs -c ~/.config/quickshell/caelestia/shell.qml"
EOF
chmod +x ~/repair_caelestia.sh
bash ~/repair_caelestia.sh