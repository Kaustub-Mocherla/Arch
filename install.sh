#!/bin/bash

set -e

echo -e "\n== Arch Linux Installer: Custom Setup ==\n"

echo "== Step 1: Checking Internet Connectivity =="
if ping -c 1 archlinux.org > /dev/null 2>&1; then
  echo "[✓] Internet is working."
else
  echo "[✗] Internet connection failed. Please connect and retry."
  exit 1
fi

echo -e "\n== Step 2: Installing git and curl if missing =="

# Use fallback if pacman fails initially
if ! pacman -Sy --noconfirm git curl reflector > /dev/null 2>&1; then
  echo "[!] pacman failed, retrying with mirrorlist update..."
  sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
  reflector --country 'India' --age 6 --sort rate --save /etc/pacman.d/mirrorlist
  pacman -Syyu --noconfirm
  pacman -Sy --noconfirm git curl reflector || {
    echo "[✗] Failed to install required packages."
    exit 1
  }
fi

echo -e "\n== Step 3: Updating Mirrorlist with Reflector =="
reflector --country 'India' --age 6 --sort rate --save /etc/pacman.d/mirrorlist || echo "[!] Reflector failed, continuing with default mirrors."

echo -e "\n== Step 4: Cloning Installer Repo =="
cd ~
rm -rf ArchSetup
git clone https://github.com/Kaustub-Mocherla/ArchSetup.git || {
  echo "[✗] Git clone failed. Check your internet or repo URL."
  exit 1
}
cd ArchSetup

echo -e "\n== Step 5: Running install script ==\n"

chmod +x install.sh
./install.sh || {
  echo "[✗] install.sh failed to execute."
  exit 1
}
