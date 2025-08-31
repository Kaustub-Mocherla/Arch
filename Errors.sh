# Make sure target folder exists
mkdir -p ~/.config/quickshell/caelestia

# Re-clone the shell repo
rm -rf ~/.cache/caelestia-shell
git clone --depth=1 https://github.com/caelestia-dots/shell ~/.cache/caelestia-shell

# Copy shell.qml and modules explicitly
cp ~/.cache/caelestia-shell/shell.qml ~/.config/quickshell/caelestia/
cp -r ~/.cache/caelestia-shell/modules ~/.config/quickshell/caelestia/

echo "[✓] Copied Caelestia files."
echo "Try running now: caelestia-shell"