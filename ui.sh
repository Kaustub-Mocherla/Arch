#!/usr/bin/env bash
set -euo pipefail

# ----- Cooldown wrapper for Caelestia install.fish -----
# Throttles heavy steps, auto-pauses on high CPU temps, fixes swww conflict.

# You can override these when running:
#   MAX_TEMP=80 CHECK_EVERY=15 bash run_cool_install.sh
MAX_TEMP="${MAX_TEMP:-85}"          # °C threshold
CHECK_EVERY="${CHECK_EVERY:-10}"    # seconds between checks

CAEL_REPO="$HOME/.local/share/caelestia"
CAEL_URL="https://github.com/caelestia-dots/shell.git"
LOG="$HOME/caelestia_cool_install_$(date +%F_%H%M%S).log"

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }

# ----- logging -----
exec > >(tee -a "$LOG") 2>&1

# ----- small helpers -----
have(){ command -v "$1" >/dev/null 2>&1; }
cpu_temp() {
  local t
  t="$(sensors 2>/dev/null | \
      awk '/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{
              for(i=1;i<=NF;i++) if($i~/[0-9]+(\.[0-9]+)?°C/){gsub(/[+°C]/,"",$i); print $i+0}
           }' | sort -nr | head -n1)"
  echo "${t:-0}"
}
cool_wait() {
  if ! have sensors; then sudo pacman -S --needed --noconfirm lm_sensors; fi
  local t; t="$(cpu_temp)"
  echo "CPU temp: ${t}°C (limit ${MAX_TEMP}°C)"
  while [ "${t%.*}" -ge "$MAX_TEMP" ]; do
    echo "… cooling (waiting ${CHECK_EVERY}s)"
    sleep "$CHECK_EVERY"
    t="$(cpu_temp)"; echo "  -> ${t}°C"
  done
}
pac(){ cool_wait; sudo pacman -S --needed --noconfirm "$@"; }

# ----- prerequisites -----
say "Installing minimal prerequisites…"
pac lm_sensors fish git

# Fix swww conflict up front (keep -git when possible)
if pacman -Qi swww &>/dev/null; then
  say "Removing stable swww (conflicts with swww-git)…"
  sudo pacman -Rns --noconfirm swww || true
fi

# ----- get Caelestia repo -----
if [[ -d "$CAEL_REPO/.git" ]]; then
  say "Updating Caelestia repo…"
  git -C "$CAEL_REPO" pull --ff-only
else
  say "Cloning Caelestia repo…"
  mkdir -p "$(dirname "$CAEL_REPO")"
  git clone "$CAEL_URL" "$CAEL_REPO"
fi

# ----- create a fish runner that throttles heavy commands -----
RUNF="$CAEL_REPO/.cool_run_install.fish"
say "Preparing heat-safe fish runner…"

cat >"$RUNF" <<'FISH'
# Imported from environment:
#   MAX_TEMP, CHECK_EVERY
function __cool_get_temp
  bash -lc 'sensors 2>/dev/null | awk "/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{for(i=1;i<=NF;i++) if(\$i~/[0-9]+(\.[0-9]+)?°C/){gsub(/[+°C]/,\"\",$i); print \$i+0}}\" | sort -nr | head -n1'
end

function cool_wait
  if not type -q sensors
    sudo pacman -S --needed --noconfirm lm_sensors >/dev/null 2>&1
  end
  set -l t (__cool_get_temp)
  if test -z "$t"
    set t 0
  end
  echo "CPU temp: $t°C (limit $MAX_TEMP°C)"
  while test (math "floor($t)") -ge $MAX_TEMP
    echo "… cooling (sleep $CHECK_EVERY s)"
    sleep $CHECK_EVERY
    set t (__cool_get_temp)
  end
end

# Lower heat while building
set -x MAKEFLAGS -j1
set -x CFLAGS "-O2"
set -x CXXFLAGS "-O2"

# Save originals if defined
functions -q yay;    and functions -c yay    __orig_yay
functions -q paru;   and functions -c paru   __orig_paru
functions -q pacman; and functions -c pacman __orig_pacman
functions -q makepkg;and functions -c makepkg __orig_makepkg
functions -q git;    and functions -c git    __orig_git
functions -q cmake;  and functions -c cmake  __orig_cmake
functions -q ninja;  and functions -c ninja  __orig_ninja

# Wrap with cool_wait + nice/ionice
function yay;    cool_wait; command nice -n 19 ionice -c3 __orig_yay $argv;    end
function paru;   cool_wait; command nice -n 19 ionice -c3 __orig_paru $argv;   end
function pacman; cool_wait; command nice -n 19 ionice -c3 __orig_pacman $argv; end
function makepkg;cool_wait; command nice -n 19 ionice -c3 __orig_makepkg $argv;end
function git;    cool_wait; command nice -n 19 ionice -c3 __orig_git $argv;    end
function cmake;  cool_wait; command nice -n 19 ionice -c3 __orig_cmake $argv;  end
function ninja;  cool_wait; command nice -n 19 ionice -c3 __orig_ninja $argv;  end

# Prefer swww-git if yay exists; otherwise leave to installer
if not command -q swww
  if command -q yay
    cool_wait
    command nice -n 19 ionice -c3 yay -S --needed --noconfirm swww-git
  end
end

# Run upstream installer exactly as-is
source ~/.local/share/caelestia/install.fish
FISH

# ----- run it -----
export MAX_TEMP CHECK_EVERY
say "Starting Caelestia install with cooldown wrapper…"
fish "$RUNF"

say "Done. Log: $LOG"
echo "If heat is still high, try: MAX_TEMP=80 CHECK_EVERY=15 bash run_cool_install.sh"