#!/bin/bash

set -e

echo "== Step 1: Ensuring Network Connection =="

# Test connection
if ping -q -c 2 archlinux.org > /dev/null; then
    echo "[✓] Internet connected"
else
    echo "[✗] No Internet connection. Exiting..."
    exit 1
fi

echo "== Step 2: Installing Reflector (if missing) =="

if ! command -v reflector &> /dev/null; then
    echo "[*] Installing reflector..."
    sudo pacman -Sy --noconfirm reflector || {
        echo "[✗] Failed to install reflector. Aborting..."
        exit 1
    }
else
    echo "[✓] Reflector is already installed"
fi

echo "== Step 3: Updating Mirrorlist with Fastest Servers =="

if ! sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist --verbose --timeout 10; then
    echo "[!] Reflector failed, using default mirrorlist"
else
    echo "[✓] Mirrorlist updated"
fi

echo "== Step 4: System Sync and Basic Tools =="

sudo pacman -Syyu --noconfirm
sudo pacman -S --needed --noconfirm git curl base-devel

echo "== Step 5: Enable NetworkManager =="

sudo pacman -S --noconfirm networkmanager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager || {
    echo "[!] Could not start NetworkManager, check manually"
}

echo "== Step 6: Clone Setup Repo =="

rm -rf ArchSetup
if git clone https://github.com/Kaustub-Mocherla/Arch.git ArchSetup; then
    echo "[✓] Cloned Arch repo"
else
    echo "[✗] Failed to clone repo. Check your internet or repo URL"
    exit 1
fi

echo "== Step 7: Run the Main Installer =="

cd ArchSetup
chmod +x install_celestia_arch.sh

if [[ -f install_celestia_arch.sh ]]; then
    echo "[*] Starting full Arch setup..."
    ./install_celestia_arch.sh
else
    echo "[✗] Script 'install_celestia_arch.sh' not found in repo. Exiting..."
    exit 1
fi

echo "[✓] All Done. If you saw errors, scroll up and fix manually."
