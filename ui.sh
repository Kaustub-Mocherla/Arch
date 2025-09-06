#!/usr/bin/env bash
set -euo pipefail

# ===== Cooldown wrapper for Caelestia install.fish =====
# Runs install.fish safely on thermally constrained laptops.

MAX_TEMP="${MAX_TEMP:-85}"      # °C threshold to pause
CHECK_EVERY="${CHECK_EVERY:-10}"# seconds between temperature checks
REPO="${REPO:-$HOME/.local/share/caelestia}"
REPO_URL="https://github.com/caelestia-dots/shell.git"
LOG="$HOME/caelestia_cool_install_$(date +%F_%H%M%S).log"

say(){ printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }

exec > >(tee -a "$LOG") 2>&1

say "Installing minimal tools used by the wrapper…"
sudo pacman -S --needed --noconfirm lm_sensors fish git

# swww conflict guard (keep swww-git preference)
if pacman -Qi swww &>/dev/null; then
  say "Removing stable 'swww' (conflicts with swww-git)…"
  sudo pacman -Rns --noconfirm swww || true
fi

# Get Caelestia repo (if not present)
if [[ -d "$REPO/.git" ]]; then
  say "Updating Caelestia repo…"
  git -C "$REPO" pull --ff-only
else
  say "Cloning Caelestia repo…"
  mkdir -p "$(dirname "$REPO")"
  git clone "$REPO_URL" "$REPO"
fi

# Create a temporary fish runner that injects cooldown + throttling
RUNF="$REPO/.cool_run_install.fish"
say "Preparing cooldown wrapper (Fish)…"

cat > "$RUNF" <<'FISH'
# ---- Cooldown + throttling helpers (Fish) ----

function __cool_get_temp --description "read hottest CPU temp in °C"
  # delegate parsing to bash+awk for simplicity
  set -l t (bash -lc 'sensors 2>/dev/null | awk "/Tctl:|Package id 0:|Tdie:|CPU temp:|CPU Temperature:|temp1:/{for(i=1;i<=NF;i++) if(\$i~/[0-9]+(\\.[0-9]+)?°C/){gsub(/[+°C]/,\"\",$i); print \$i+0}}" | sort -nr | head -n1')
  if test -z "$t"
    echo 0
  else
    echo $t
  end
end

function cool_wait --description "pause while temp >= $MAX_TEMP °C"
  if not type -q sensors
    sudo pacman -S --needed --noconfirm lm_sensors >/dev/null 2>&1
  end
  set -l t (__cool_get_temp)
  echo "CPU temp: $t°C (limit $MAX_TEMP°C)"
  while test (math "floor($t)") -ge $MAX_TEMP
    echo "… cooling ($t°C >= $MAX_TEMP°C). Sleeping $CHECK_EVERY s"
    sleep $CHECK_EVERY
    set t (__cool_get_temp)
  end
end

# Lower parallelism and priority to reduce heat
set -x MAKEFLAGS -j1
set -x CFLAGS "-O2"
set -x CXXFLAGS "-O2"

# Wrap heavy commands so they always cool_wait first
functions -q yay;  and functions -c yay  __orig_yay
functions -q paru; and functions -c paru __orig_paru
functions -q pacman; and functions -c pacman __orig_pacman
functions -q makepkg; and functions -c makepkg __orig_makepkg
functions -q git; and functions -c git __orig_git
functions -q cmake; and functions -c cmake __orig_cmake
functions -q ninja; and functions -c ninja __orig_ninja

function yay
  cool_wait
  command nice -n 19 ionice -c3 __orig_yay $argv
end
function paru
  cool_wait
  command nice -n 19 ionice -c3 __orig_paru $argv
end
function pacman
  cool_wait
  command nice -n 19 ionice -c3 __orig_pacman $argv
end
function makepkg
  cool_wait
  command nice -n 19 ionice -c3 __orig_makepkg $argv
end
function git
  cool_wait
  command nice -n 19 ionice -c3 __orig_git $argv
end
function cmake
  cool_wait
  command nice -n 19 ionice -c3 __orig_cmake $argv
end
function ninja
  cool_wait
  command nice -n 19 ionice -c3 __orig_ninja $argv
end

# Prefer swww-git if yay exists, else let upstream handle it
if not command -q swww
  if command -q yay
    cool_wait
    command nice -n 19 ionice -c3 yay -S --needed --noconfirm swww-git
  end
end

# Finally, run the real installer from the repo (exactly like the video)
source ~/.local/share/caelestia/install.fish
FISH

# Run the wrapped installer
say "Starting Caelestia install.fish with cooldown wrapper…"
fish "$RUNF"

say "All done. If heat still spikes:"
echo "  • You can lower MAX_TEMP or increase CHECK_EVERY:"
echo "      MAX_TEMP=80 CHECK_EVERY=15 bash run_cool_install.sh"
echo "  • Log saved to: $LOG"