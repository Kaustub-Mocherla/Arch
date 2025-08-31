# Re-seed the Caelestia files cleanly (idempotent)
bash -lc '
  set -e
  rm -rf ~/.config/quickshell/caelestia
  mkdir -p ~/.config/quickshell/caelestia
  git clone --depth=1 https://github.com/caelestia-dots/shell ~/.cache/caelestia-src/shell
  cp -a ~/.cache/caelestia-src/shell/shell.qml ~/.config/quickshell/caelestia/
  cp -a ~/.cache/caelestia-src/shell/modules ~/.config/quickshell/caelestia/
'
# then:
caelestia-shell