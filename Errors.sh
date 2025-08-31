# === Caelestia: fix + clean install (user-scoped) ===
set -euo pipefail

x() { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
e() { printf "\033[1;31m[!] %s\033[0m\n" "$*" >&2; }

CONF="$HOME/.config/quickshell/caelestia"
MODS="$CONF/modules"
CACHE="$HOME/.cache/caelestia-shell"

x "Ensuring QuickShell + git are present… (safe if already installed)"
if command -v sudo >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm quickshell git >/dev/null
else
  e "sudo not found; skipping package install step"
fi

x "Preparing config dirs"
mkdir -p "$CONF"

x "Fetching shell repo fresh"
rm -rf "$CACHE"
git clone --depth=1 https://github.com/caelestia-dots/shell "$CACHE"

x "Copying shell.qml and modules to $CONF"
cp -f "$CACHE/shell.qml" "$CONF/"
rm -rf "$MODS"
cp -a "$CACHE/modules" "$MODS"

x "Setting sane permissions"
chmod 644 "$CONF/shell.qml"
find "$MODS" -type d -exec chmod 755 {} \;
find "$MODS" -type f -exec chmod 644 {} \;

x "Creating launcher wrapper: ~/.local/bin/caelestia-shell"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/caelestia-shell" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CONF="$HOME/.config/quickshell/caelestia"
# Make Caelestia QML modules visible to QuickShell
export QML2_IMPORT_PATH="$CONF/modules${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
# Launch by ABSOLUTE FILE PATH (avoids 'config directory not found')
exec quickshell "$CONF/shell.qml"
EOS
chmod +x "$HOME/.local/bin/caelestia-shell"

# Ensure ~/.local/bin is on PATH for this and future shells
if ! grep -q '\.local/bin' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi
export PATH="$HOME/.local/bin:$PATH"

# Sanity checks
x "Verifying files:"
ls -la "$CONF"
test -f "$CONF/shell.qml" || { e "shell.qml missing"; exit 1; }
test -d "$MODS" || { e "modules/ missing"; exit 1; }

x "Wrapper on PATH: $(command -v caelestia-shell || echo 'NOT FOUND')"
x "Done. Inside Hyprland, run:  caelestia-shell"