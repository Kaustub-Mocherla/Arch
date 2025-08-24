#!/bin/bash

# Full Arch Linux Install Script with Robust Error Handling
# Author: ChatGPT + Kaustub Mocherla
# Logs everything to /tmp/arch_install.log

LOGFILE=/tmp/arch_install.log
exec > >(tee -a "$LOGFILE") 2>&1

echo "=========================================="
echo "     Arch Linux Full Setup Script"
echo "   With Resilience and Fallback Handling"
echo "=========================================="

set -e

step() {
  echo -e "\n>>> [STEP] $1\n"
}

error_exit() {
  echo -e "\n[ERROR] $1"
  echo "Exiting installation. Check log at $LOGFILE"
  exit 1
}

# STEP 1: Check Internet
step "Checking Internet Connectivity..."
if ! ping -c 1 archlinux.org > /dev/null 2>&1; then
  error_exit "No internet connection. Connect and try again."
fi

# STEP 2: Sync Time
step "Setting system clock with NTP..."
timedatectl set-ntp true || echo "[WARN] Could not sync clock."

# STEP 3: Refresh Keyring
step "Refreshing pacman and keyring..."
pacman -Sy --noconfirm archlinux-keyring || error_exit "Failed to sync archlinux-keyring."
pacman-key --init && pacman-key --populate archlinux || echo "[WARN] Keyring population failed."

# STEP 4: Install tools
step "Installing git, curl, reflector..."
if ! pacman -Sy --noconfirm reflector git curl; then
  echo "[WARN] Default mirror failed. Updating mirrorlist manually..."
  curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/ || error_exit "Mirrorlist download failed."
  sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
  pacman -Syy --noconfirm reflector git curl || error_exit "Even fallback install failed."
fi

# STEP 5: Optimize Mirrors
step "Running reflector to sort mirrors..."
reflector --country India --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || echo "[WARN] Reflector failed, using default mirrors."

# STEP 6: Clone Your Repo
step "Cloning your repo from GitHub..."
cd ~
rm -rf ArchSetup
if ! git clone https://github.com/Kaustub-Mocherla/ArchSetup.git; then
  error_exit "Git clone failed. Check network or repo URL."
fi
cd ArchSetup || error_exit "Cloned repo folder not found."

# STEP 7: Run install.sh
step "Running your install.sh script..."
if [[ -f install.sh ]]; then
  chmod +x install.sh
  ./install.sh || error_exit "install.sh failed. See $LOGFILE for details."
else
  error_exit "install.sh not found in cloned repo."
fi

echo -e "\n✅ Arch base installation completed successfully!"
