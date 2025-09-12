#!/usr/bin/env bash
set -euo pipefail

# ===== Helpers =====
green() { printf "\e[32m%s\e[0m\n" "$*"; }
yellow() { printf "\e[33m%s\e[0m\n" "$*"; }
red() { printf "\e[31m%s\e[0m\n" "$*"; }

append_if_missing() {
  # $1=file, $2=needle (regex), $3=block to append
  local file="$1" needle="$2" block="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Eq "$needle" "$file"; then
    printf "\n# --- added by setup-ml4w-hyprland-audio-bt-scrcpy on %s ---\n%s\n" "$(date)" "$block" >> "$file"
    green "Updated: $file"
  else
    yellow "Already present in: $file (skipped)"
  fi
}

backup_once() {
  local file="$1"
  if [[ -f "$file" && ! -f "$file.bak" ]]; then
    cp -a "$file" "$file.bak"
    yellow "Backup created: $file.bak"
  fi
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { red "Missing command: $1"; exit 1; }; }

# ===== Pre-flight =====
require_cmd sudo
if ! grep -qiE 'arch|manjaro|endeavouros|garuda|artix' /etc/*-release 2>/dev/null; then
  yellow "This script targets Arch-based systems. Continuing anyway…"
fi

USER_CONFIG_HYPR="${HOME}/.config/hypr/hyprland.conf"
USER_CONFIG_WAYBAR="${HOME}/.config/waybar/config.jsonc"
USER_STYLE_WAYBAR="${HOME}/.config/waybar/style.css"
USER_BIN="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

mkdir -p "$USER_BIN" "$SYSTEMD_USER_DIR"

green "1) Install packages (audio, tray, bluetooth, android)…"
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol waybar \
  bluez bluez-utils blueman \
  scrcpy android-tools android-udev

green "2) Enable services…"
# PipeWire/WirePlumber user services (socket-activated, but enable to be safe)
systemctl --user enable --now pipewire.service pipewire.socket wireplumber.service || true
# Bluetooth daemon
sudo systemctl enable --now bluetooth.service
# Reload udev rules so android-udev takes effect
sudo udevadm control --reload-rules
sudo udevadm trigger

green "3) Hyprland keybinds (PipeWire-native volume + media + scrcpy) and autostart…"
backup_once "$USER_CONFIG_HYPR"

HYPR_BLOCK=$(cat <<'EOF'
# === Audio (PipeWire via wpctl) ===
bind = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = ,XF86AudioMute,        exec, wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle

# === Media keys (requires playerctl; optional) ===
# pacman -S playerctl
# bind = ,XF86AudioPlay,  exec, playerctl play-pause
# bind = ,XF86AudioNext,  exec, playerctl next
# bind = ,XF86AudioPrev,  exec, playerctl previous

# === scrcpy launchers ===
# Quick launch (USB or Wi-Fi if set up)
bind = SUPER, P, exec, scrcpy
# Safer: wait for USB device and then launch with reasonable defaults
bind = SUPER SHIFT, P, exec, ~/.local/bin/scrcpy-usb.sh

# === Autostart Waybar + Blueman tray ===
exec-once = waybar
exec-once = blueman-applet
EOF
)
append_if_missing "$USER_CONFIG_HYPR" 'wpctl set-volume @DEFAULT_AUDIO_SINK@' "$HYPR_BLOCK"

green "4) Waybar minimal config (only created if missing)…"
if [[ ! -f "$USER_CONFIG_WAYBAR" ]]; then
  mkdir -p "$(dirname "$USER_CONFIG_WAYBAR")"
  cat > "$USER_CONFIG_WAYBAR" <<'JSONC'
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "modules-left": ["hyprland/workspaces"],
  "modules-right": ["pulseaudio", "bluetooth", "network", "battery", "clock"],
  "pulseaudio": {
    "format": "{volume}% ",
    "format-muted": "",
    "on-click": "pavucontrol"
  },
  "bluetooth": {
    "format": " {status}",
    "format-connected": " {device_alias}",
    "format-disabled": " off",
    "on-click": "blueman-manager"
  },
  "network": {
    "format-wifi": " {essid} {signalStrength}%",
    "format-ethernet": " {ifname}",
    "format-disconnected": "󰤭",
    "on-click": "nm-connection-editor"
  },
  "battery": {
    "format": "{capacity}% {icon}",
    "format-icons": ["󰁺","󰁼","󰁾","󰂀","󰂂","󰁹"]
  },
  "clock": { "format": "{:%a %d %b  %H:%M}" }
}
JSONC
  green "Created: $USER_CONFIG_WAYBAR"
else
  yellow "Waybar config exists. Not overwriting."
fi
if [[ ! -f "$USER_STYLE_WAYBAR" ]]; then
  cat > "$USER_STYLE_WAYBAR" <<'CSS'
* { font-family: sans-serif; font-size: 12px; }
window#waybar { border: none; }
CSS
  green "Created: $USER_STYLE_WAYBAR"
fi

green "5) Create scrcpy helper that waits for a device (USB)…"
SCRCPY_HELPER="${USER_BIN}/scrcpy-usb.sh"
cat > "$SCRCPY_HELPER" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

# Ensure adb server is running
adb start-server >/dev/null 2>&1 || true

echo "Waiting for Android device (USB debugging must be enabled)…"
adb wait-for-device

# Optional: trust this host automatically (if prompt appears on device)
# adb devices

# Launch scrcpy with sensible defaults:
#  - Turn phone screen off to save battery (toggle with Ctrl+o)
#  - Limit size for performance; remove --max-size to mirror full res
exec scrcpy --turn-screen-off --stay-awake --max-size 1440
BASH
chmod +x "$SCRCPY_HELPER"
green "Created: $SCRCPY_HELPER"

green "6) Start ADB server automatically at login (user service)…"
ADB_UNIT="${SYSTEMD_USER_DIR}/adb-user.service"
cat > "$ADB_UNIT" <<'UNIT'
[Unit]
Description=ADB server for Android debugging (user)
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/adb start-server
Restart=on-failure

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now adb-user.service

green '7) Reload Hyprland (if running)…'
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload || true
fi

green "All set! ✅"
cat <<'EON'

USB steps:
  1) On phone: Enable Developer Options → USB debugging.
  2) Plug in USB → accept "Allow USB debugging?" prompt on phone.
  3) Press Super+Shift+P to run the helper (waits for device), or Super+P for instant scrcpy.

Quick tests:
  - Volume keys move pavucontrol slider & change actual audio.
  - Waybar shows audio & BT icons; blueman-applet is in tray.
  - 'adb devices' lists your phone; 'scrcpy' opens a window.

If USB permission issues:
  - Unplug/replug phone.
  - Run: sudo udevadm control --reload-rules && sudo udevadm trigger
  - Re-accept the USB debugging prompt.

Optional (Wi-Fi mode):
  adb tcpip 5555
  adb connect PHONE_IP:5555
  scrcpy
EON