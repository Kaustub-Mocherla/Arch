bash -euo pipefail <<'EOS'
# 1) Refresh mirrors to fix slow/failed downloads
sudo pacman -S --needed --noconfirm reflector rsync
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak.$(date +%s)
# pick fast HTTPS mirrors (adjust --country as you like, or drop to use global)
sudo reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# force DB refresh
sudo pacman -Syy

# 2) Install the runtime/build deps (no app2unit)
sudo pacman -Sy --needed --noconfirm \
  git base-devel cmake ninja \
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-shadertools \
  ddcutil brightnessctl cava networkmanager lm_sensors fish \
  aubio pipewire libqalculate bash \
  swww wl-clipboard grim slurp swappy playerctl pamixer \
  noto-fonts ttf-liberation ttf-cascadia-code-nerd curl unzip
EOS