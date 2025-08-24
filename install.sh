#!/bin/bash

echo "== Arch Linux Installer: Custom Setup =="

# Step 1: Check Internet
echo "== Step 1: Checking Internet Connectivity =="
if ping -q -c 1 archlinux.org > /dev/null 2>&1; then
    echo "[✓] Internet is working."
else
    echo "[X] No internet connection. Please connect and try again."
    exit 1
fi

# Step 2: Fix mirrors manually with fallback
echo "== Step 2: Fixing Mirrorlist =="
echo "Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch" | sudo tee /etc/pacman.d/mirrorlist

# Step 3: Initialize keyring if not present
echo "== Step 3: Initializing Pacman Keyring =="
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Sy --noconfirm

# Step 4: Install git and curl (only if missing)
echo "== Step 4: Installing git and curl if missing =="
if command -v git >/dev/null && command -v curl >/dev/null; then
    echo "[✓] git and curl already installed."
else
    sudo pacman -S --noconfirm git curl || {
        echo "[X] Failed to install git and curl. Check mirrors or retry manually."
        exit 1
    }
fi

# Step 5: Clean up previous directory
echo "== Step 5: Cloning Installer Repo =="
rm -rf ArchSetup
git clone https://github.com/Kaustub-Mocherla/ArchSetup.git || {
    echo "[X] Git clone failed. Check your internet or the repo URL."
    exit 1
}

# Step 6: Make script executable and run
cd ArchSetup || {
    echo "[X] Failed to enter ArchSetup directory."
    exit 1
}

chmod +x install_celestia_arch.sh

if [[ ! -f install_celestia_arch.sh ]]; then
    echo "[X] Script file 'install_celestia_arch.sh' not found. Check repo contents."
    exit 1
fi

echo "== Step 6: Running Full Setup Script =="
./install_celestia_arch.sh || {
    echo "[X] Full setup script failed. See logs above."
    exit 1
}

echo "[✓] Arch Linux Custom Setup Completed Successfully!"
