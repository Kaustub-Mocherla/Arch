mkdir -p ~/.config/quickshell/caelestia

# Clone latest Caelestia shell repo
rm -rf ~/.cache/caelestia-shell
git clone --depth=1 https://github.com/caelestia-dots/shell ~/.cache/caelestia-shell

# Copy shell.qml and modules to the right place
cp -f ~/.cache/caelestia-shell/shell.qml ~/.config/quickshell/caelestia/
cp -rf ~/.cache/caelestia-shell/modules ~/.config/quickshell/caelestia/

echo "[✓] Caelestia shell.qml and modules installed in ~/.config/quickshell/caelestia"

# Run once to test
caelestia-shell