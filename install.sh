#!/usr/bin/env bash
set -euo pipefail

# ============ helpers ============
bold(){ printf "\e[1m%s\e[0m\n" "$*"; }
note(){ printf "\n\e[36m==> %s\e[0m\n" "$*"; }
warn(){ printf "\n\e[33m[warn]\e[0m %s\n" "$*"; }
die(){ printf "\n\e[31m[fail]\e[0m %s\n" "$*"; exit 1; }

if [[ $EUID -eq 0 ]]; then
  die "Run this as your normal user from TTY (not with sudo). I will sudo when needed."
fi

ME_USER="${USER}"
ME_HOME="$(getent passwd "$ME_USER" | cut -d: -f6)"
TS="$(date +%F_%H%M%S)"
LOG="$ME_HOME/hypr_one_fix_${TS}.log"
exec > >(tee -a "$LOG") 2>&1

bold "Hyprland one-shot repair • log: $LOG"

# ============ 0) Basic sanity ============
note "Checking internet and pacman database lock…"
ping -c1 -W2 archlinux.org >/dev/null 2>&1 || warn "No ping; assuming network is OK via mirror. Continuing."
if sudo fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
  note "Removing stale pacman lock"
  sudo rm -f /var/lib/pacman/db.lck || true
fi

# ============ 1) Resolve swww vs swww-git conflict ============
note "Normalizing swww package (remove conflict and install swww-git)…"
if pacman -Q swww >/dev/null 2>&1; then
  sudo pacman -Rns --noconfirm swww || true
fi
# Install/keep swww-git (fits your earlier setup and avoids conflict prompts)
if ! pacman -Q swww-git >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git || true
  # Try regular repo first (some mirrors carry it), fallback to AUR helperless build
  if ! sudo pacman -S --needed --noconfirm swww-git; then
    note "Building swww-git from AUR (no helper)…"
    TMPD="$(mktemp -d)"
    trap 'rm -rf "$TMPD"' EXIT
    ( cd "$TMPD" && git clone https://aur.archlinux.org/swww-git.git && cd swww-git && makepkg -si --noconfirm )
  fi
fi

# ============ 2) Core packages (skip already-installed) ============
note "Installing core Hyprland stack (skipping installed ones)…"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm \
  hyprland waybar wofi kitty mako \
  hyprpaper xdg-desktop-portal-hyprland polkit-gnome \
  wl-clipboard grim slurp brightnessctl network-manager-applet \
  noto-fonts ttf-jetbrains-mono noto-fonts-emoji lm_sensors

# Optional but useful for GPU/input perms
sudo pacman -S --needed --noconfirm libinput

# ============ 3) Ensure SDDM session entry ============
note "Ensuring Hyprland session file exists…"
SESSION_FILE="/usr/share/wayland-sessions/hyprland.desktop"
if [[ ! -f "$SESSION_FILE" ]]; then
  sudo tee "$SESSION_FILE" >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
fi

# Optionally make SDDM default to Hyprland
note "Setting SDDM default session to Hyprland (non-fatal if SDDM absent)…"
sudo install -d -m 755 /etc/sddm.conf.d || true
sudo tee /etc/sddm.conf.d/10-session.conf >/dev/null <<'EOF'
[Autologin]
Relogin=false

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
# keep default

[Users]
HideShells=/sbin/nologin,/bin/false

[Wayland]
Session=hyprland.desktop
EOF

# ============ 4) Fix user groups (input/video/render/seat) ============
note "Adding user to input/video/render/seat groups…"
# (Groups may not exist on all distros; ignore failures)
for g in input video render seat; do
  if getent group "$g" >/dev/null 2>&1; then
    sudo usermod -aG "$g" "$ME_USER" || true
  fi
done

# ============ 5) Minimal safe configs ============
CFG="$ME_HOME/.config"
HYPR_DIR="$CFG/hypr"
WB_DIR="$CFG/waybar"
HP_DIR="$CFG/hyprpaper"
WO_DIR="$CFG/wofi"

note "Backing up any existing configs…"
mkdir -p "$ME_HOME/.config_backup_hypr_fix_$TS"
for d in hypr waybar hyprpaper wofi; do
  if [[ -e "$CFG/$d" ]]; then
    mv "$CFG/$d" "$ME_HOME/.config_backup_hypr_fix_$TS/" || true
  fi
done

note "Writing minimal Hyprland config…"
mkdir -p "$HYPR_DIR" "$WB_DIR" "$HP_DIR" "$WO_DIR"

# Minimal hyprland.conf – no wallpaper/autostart that can crash; only waybar+kitty
cat > "$HYPR_DIR/hyprland.conf" <<'EOF'
# ---------- minimal, safe Hyprland config ----------
monitor=,preferred,auto,1

# XDG portal (prevents apps from complaining)
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Cursor
exec-once = hyprctl setcursor default 24

# Panel + terminal (safe)
exec-once = waybar
exec-once = kitty

# Keybinds
$mod = SUPER
bind = $mod, Q, exec, kitty
bind = $mod, D, exec, wofi --show drun
bind = $mod, C, killactive
bind = $mod, Return, fullscreen, 0
bind = $mod, F, togglefloating
bind = $mod, E, exec, wofi --show run
bind = $mod, S, exec, systemctl --user restart waybar

# Basic animations off (safer on weak iGPU)
animations {
  enabled = no
}

misc {
  disable_hyprland_logo = true
  vfr = true
}

# Window rules sane defaults
general {
  gaps_in = 5
  gaps_out = 10
  border_size = 2
  layout = dwindle
  allow_tearing = false
}

input {
  kb_layout = us
  follow_mouse = 1
  touchpad {
    natural_scroll = true
    disable_while_typing = true
  }
}
EOF

note "Writing minimal Waybar config…"
mkdir -p "$WB_DIR"
cat > "$WB_DIR/config.jsonc" <<'EOF'
// Minimal safe Waybar
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-center": [],
  "modules-right": ["network","pulseaudio","battery"],
  "clock": { "format": "{:%a %d %b %H:%M}" },
  "network": { "format-wifi": "{ssid} ({signalStrength}%)", "format-ethernet": "eth", "format-disconnected": "offline" },
  "pulseaudio": { "format": "{volume}%" },
  "battery": { "format": "{capacity}%" }
}
EOF
cat > "$WB_DIR/style.css" <<'EOF'
* { font-family: JetBrainsMono Nerd Font, monospace; font-size: 12px; }
window { background: transparent; }
#clock, #network, #pulseaudio, #battery { padding: 0 8px; }
EOF

note "Writing tiny Wofi config…"
cat > "$WO_DIR/config" <<'EOF'
prompt=Run:
show=drun
width=50%
height=50%
allow_images=false
EOF

# Do NOT autostart wallpaper to avoid compositor crashes; user can enable later
note "Hyprpaper/swww not auto-started to avoid crash loops. You can enable after session works."

# Permissions sanity
sudo chown -R "$ME_USER":"$ME_USER" "$CFG" "$ME_HOME/.config_backup_hypr_fix_$TS"

# ============ 6) Portal & polkit on login ============
note "User-level systemd units for portal/polkit…"
SYSTEMD_USER="$ME_HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER"

cat > "$SYSTEMD_USER/polkit-gnome.service" <<'EOF'
[Unit]
Description=Polkit GNOME agent
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/polkit-gnome-authentication-agent-1
Restart=no

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload || true
systemctl --user enable --now polkit-gnome.service || true

# ============ 7) Final hints ============
note "DONE. Now:"
echo "  1) Reboot:    sudo reboot"
echo "  2) In SDDM:   choose *Hyprland* session, log in."
echo "  3) You should get Waybar (top) and a Kitty terminal."
echo ""
echo "If you still bounce back to SDDM:"
echo "  • Switch to TTY (Ctrl+Alt+F3), log in and run:  Hyprland --verbose"
echo "    Paste the last ~20 lines so we can see the exact error."