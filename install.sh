#!/usr/bin/env bash
set -euo pipefail

# ===== Caelestia-shell full installer (with cleanup + heat-safe + no-blank fallback) =====
# Optional: MAX_TEMP=80 CHECK_EVERY=15 bash install_caelestia_allinone.sh
MAX_TEMP="${MAX_TEMP:-85}"           # °C – pause above this
CHECK_EVERY="${CHECK_EVERY:-10}"     # seconds between temp checks

LOG="$HOME/caelestia_full_$(date +%F_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

cpu_temp() {
  local t
  t="$(sensors 2>/dev/null | awk '/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{
    for(i=1;i<=NF;i++) if($i~/[0-9]+(\.[0-9]+)?°C/){gsub(/[+°C]/,"",$i); print $i+0}
  }' | sort -nr | head -n1)"
  echo "${t:-0}"
}
cool_wait() {
  if ! have sensors; then sudo pacman -S --needed --noconfirm lm_sensors; fi
  local t; t="$(cpu_temp)"
  echo "CPU temp: ${t}°C (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "… cooling (sleep ${CHECK_EVERY}s)"; sleep "$CHECK_EVERY"
    t="$(cpu_temp)"; echo "  -> ${t}°C"
  done
}
pac(){ cool_wait; sudo pacman -S --needed --noconfirm "$@"; }

# -----------------------------------------------------------------------------------------
# 0) Stop stray processes & prep
# -----------------------------------------------------------------------------------------
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
pkill -x swww 2>/dev/null || true
pkill -x mako 2>/dev/null || true

say "Install prerequisites…"
pac base-devel git fish lm_sensors

# yay (AUR helper)
if ! have yay; then
  say "Installing yay…"
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  ( cd "$tmpdir/yay"; cool_wait; nice -n 19 ionice -c3 makepkg -si --noconfirm )
  rm -rf "$tmpdir"
fi

# -----------------------------------------------------------------------------------------
# 1) Resolve swww conflict + Caelestia CLI
# -----------------------------------------------------------------------------------------
if pacman -Qi swww &>/dev/null; then
  say "Removing stable swww (conflicts with swww-git)…"
  sudo pacman -Rns --noconfirm swww || true
fi

say "Install swww-git + caelestia-cli-git (AUR)…"
cool_wait
nice -n 19 ionice -c3 yay -S --needed --noconfirm swww-git caelestia-cli-git

# -----------------------------------------------------------------------------------------
# 2) Core Wayland/Hyprland stack
# -----------------------------------------------------------------------------------------
say "Install Hyprland + runtime…"
pac hyprland sddm waybar wofi kitty mako hyprpaper \
    wl-clipboard grim slurp jq \
    pipewire pipewire-pulse wireplumber \
    polkit-gnome xdg-desktop-portal-hyprland \
    noto-fonts ttf-jetbrains-mono ttf-font-awesome imagemagick

# SDDM session file & services
say "Configure SDDM for Hyprland…"
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session (Wayland)
Exec=dbus-run-session /usr/bin/Hyprland
Type=Application
EOF
sudo systemctl enable --now sddm || true
sudo systemctl enable --now NetworkManager || true
sudo systemctl enable --now bluetooth || true

# -----------------------------------------------------------------------------------------
# 3) Clean End-4 leftovers and BACKUP your configs
# -----------------------------------------------------------------------------------------
say "Backup current configs (fish, hypr, waybar, wofi, kitty)…"
BKP="$HOME/.config_backup_cael_$(date +%F_%H%M%S)"
mkdir -p "$BKP"
for d in fish hypr waybar wofi kitty; do
  if [ -e "$HOME/.config/$d" ]; then
    mv "$HOME/.config/$d" "$BKP/" || true
  fi
done
rm -rf "$HOME/dots-hyprland" 2>/dev/null || true   # End-4 clone path (if any)

# -----------------------------------------------------------------------------------------
# 4) Clone/update Caelestia repo
# -----------------------------------------------------------------------------------------
CAEL_DIR="$HOME/.local/share/caelestia"
say "Fetch Caelestia repo…"
mkdir -p "$(dirname "$CAEL_DIR")"
if [[ -d "$CAEL_DIR/.git" ]]; then
  git -C "$CAEL_DIR" pull --ff-only
else
  git clone https://github.com/caelestia-dots/shell.git "$CAEL_DIR"
fi

# -----------------------------------------------------------------------------------------
# 5) Heat-safe wrapper and run upstream install.fish
# -----------------------------------------------------------------------------------------
RUNF="$CAEL_DIR/.cool_run_install.fish"
say "Create heat-safe Fish runner…"
cat >"$RUNF" <<'FISH'
function __cool_get_temp
  bash -lc 'sensors 2>/dev/null | awk "/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{for(i=1;i<=NF;i++) if(\$i~/[0-9]+(\\.[0-9]+)?°C/){gsub(/[+°C]/,\"\",$i); print \$i+0}}\" | sort -nr | head -n1'
end
function cool_wait
  if not type -q sensors
    sudo pacman -S --needed --noconfirm lm_sensors >/dev/null 2>&1
  end
  set -l t (__cool_get_temp); test -z "$t"; and set t 0
  echo "CPU temp: $t°C (limit $MAX_TEMP°C)"
  while test (math "floor($t)") -ge $MAX_TEMP
    echo "… cooling (sleep $CHECK_EVERY s)"; sleep $CHECK_EVERY
    set t (__cool_get_temp)
  end
end
set -x MAKEFLAGS -j1
set -x CFLAGS "-O2"
set -x CXXFLAGS "-O2"

functions -q yay;    and functions -c yay    __orig_yay
functions -q paru;   and functions -c paru   __orig_paru
functions -q pacman; and functions -c pacman __orig_pacman
functions -q makepkg;and functions -c makepkg __orig_makepkg
functions -q git;    and functions -c git    __orig_git
functions -q cmake;  and functions -c cmake  __orig_cmake
functions -q ninja;  and functions -c ninja  __orig_ninja
function yay;    cool_wait; command nice -n 19 ionice -c3 __orig_yay $argv;    end
function paru;   cool_wait; command nice -n 19 ionice -c3 __orig_paru $argv;   end
function pacman; cool_wait; command nice -n 19 ionice -c3 __orig_pacman $argv; end
function makepkg;cool_wait; command nice -n 19 ionice -c3 __orig_makepkg $argv;end
function git;    cool_wait; command nice -n 19 ionice -c3 __orig_git $argv;    end
function cmake;  cool_wait; command nice -n 19 ionice -c3 __orig_cmake $argv;  end
function ninja;  cool_wait; command nice -n 19 ionice -c3 __orig_ninja $argv;  end

# Run upstream installer (exactly like the video)
source ~/.local/share/caelestia/install.fish
FISH

export MAX_TEMP CHECK_EVERY
say "Run Caelestia installer…"
fish "$RUNF" || true   # allow non-fatal warnings during install

# -----------------------------------------------------------------------------------------
# 6) Force-apply Caelestia dotfiles (now that installer has placed them)
# -----------------------------------------------------------------------------------------
say "Apply Caelestia dotfiles into ~/.config (backups already made)…"
CAEL_CFG="$CAEL_DIR/config"
if [ -d "$CAEL_CFG" ]; then
  rsync -a --delete "$CAEL_CFG/" "$HOME/.config/"
fi

# Ensure rescues: wallpaper + waybar + launcher + binds
say "Ensure no-blank fallback (wallpaper + bar + binds)…"
mkdir -p "$HOME/.config/wallpapers" "$HOME/.config/hypr" "$HOME/.config/waybar"
if ! ls "$HOME/.config/wallpapers/"* >/dev/null 2>&1; then
  convert -size 1920x1080 gradient:'#1f1f28-#24283b' "$HOME/.config/wallpapers/caelestia-fallback.png"
fi
WP="$(ls -1 "$HOME/.config/wallpapers/"* | head -n1)"

# waybar minimal (only if Caelestia's file missing)
if [ ! -f "$HOME/.config/waybar/config.jsonc" ]; then
  cat > "$HOME/.config/waybar/config.jsonc" <<'JSON'
{
  "layer":"top","position":"top","height":30,
  "modules-left":["clock"],
  "modules-right":["pulseaudio","network","battery","tray"],
  "clock":{"format":"{:%a %d %b %H:%M}"},
  "pulseaudio":{"format":"{volume}%"},
  "network":{"format-wifi":"{essid} {signalStrength}%"},
  "battery":{"bat":"BAT0","format":"{capacity}%"}
}
JSON
fi

# autostart (only if Caelestia didn't already add one)
if ! grep -Rqs 'autostart.sh' "$HOME/.config/hypr"; then
  cat > "$HOME/.config/hypr/autostart.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP DESKTOP_SESSION GTK_THEME QT_QPA_PLATFORMTHEME || true
pkill -x waybar 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true
if command -v swww >/dev/null 2>&1; then
  swww init 2>/dev/null || true
  swww img "$WP" --transition-type none 2>/dev/null || true
else
  echo -e "preload = $WP\nwallpaper = ,$WP\nsplash = false" > "$HOME/.config/hypr/hyprpaper.conf"
  hyprpaper &
fi
waybar &   # bar
mako &     # notifications if installed
EOF
  chmod +x "$HOME/.config/hypr/autostart.sh"
  grep -q 'exec-once = ' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null || true
  echo 'exec-once = $HOME/.config/hypr/autostart.sh' >> "$HOME/.config/hypr/hyprland.conf"
fi

# Keybind safety net (if not already present)
if ! grep -Rqs 'wofi --show drun' "$HOME/.config/hypr"; then
  cat >> "$HOME/.config/hypr/hyprland.conf" <<'HYPR'
bind = SUPER, RETURN, exec, kitty
bind = SUPER, D, exec, wofi --show drun
bind = SUPER, Q, killactive
bind = SUPER, R, exec, hyprctl reload
HYPR
fi

# Input access to remove permission errors
if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
  echo "NOTE: you were added to 'input' group. Log out/in if input warnings persist."
fi

say "DONE. Reboot → pick Hyprland in SDDM. You should see Caelestia’s UI."
echo "Log saved to: $LOG"