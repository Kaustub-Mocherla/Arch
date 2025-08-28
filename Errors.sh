#!/usr/bin/env bash
set -e

echo -e "\n[+] Starting Caelestia repair...\n"

MODULES_DIR="$HOME/.config/quickshell/caelestia/modules"

# Clean existing modules folder
echo "[*] Cleaning old modules at $MODULES_DIR"
rm -rf "$MODULES_DIR"
mkdir -p "$MODULES_DIR"

# Try anonymous git clone first
echo "[*] Attempting anonymous git clone..."
if env -u GIT_ASKPASS -u SSH_ASKPASS -u GH_TOKEN -u GITHUB_TOKEN \
   git -c credential.helper= -c http.https://github.com/.extraheader= \
   clone --depth=1 https://github.com/caelestia-dots/modules.git "$MODULES_DIR"; then
    echo "[✔] Git clone successful!"
else
    echo "[!] Git clone failed, falling back to curl + tarball..."

    tmpdir="$(mktemp -d)"
    if curl -L https://api.github.com/repos/caelestia-dots/modules/tarball \
       | tar -xz -C "$tmpdir"; then
        firstdir="$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
        cp -r "$firstdir"/* "$MODULES_DIR"/
        rm -rf "$tmpdir"
        echo "[✔] Fallback download complete!"
    else
        echo "[✘] Both git and curl methods failed. Check your internet or GitHub availability."
        exit 1
    fi
fi

# Verify installation
echo -e "\n[*] Verifying modules..."
ls "$MODULES_DIR" | head || echo "[!] No modules found!"

echo -e "\n[+] Repair complete. You can now run:"
echo "    quickshell -c caelestia"
echo "inside Hyprland/Wayland to launch Caelestia."