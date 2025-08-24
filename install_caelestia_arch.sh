#!/bin/bash

set -e  # Exit on any error
echo -e "\n== Arch Linux Installer: Custom Setup =="

# Step 1: Check Internet
echo -e "\n== Step 1: Ensuring Network Connection =="
if ping -c 1 archlinux.org &>/dev/null; then
  echo "[✓] Internet connected"
else
  echo "[✗] Internet not available. Check your connection!"
  exit 1
fi

# Step 2: Install Reflector (optional)
echo -e "\n== Step 2: Installing Reflector (if missing) =="
if ! command -v reflector &>/dev/null; then
  sudo pacman -Sy --noconfirm reflector || echo "[!] Reflector install failed"
else
  echo "[✓] Reflector is already installed"
fi

# Step 3: Update mirrorlist with fallback
echo -e "\n== Step 3: Updating Mirrorlist with Fastest Servers (Fallback Enabled) =="
if ! timeout 20s sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist --verbose --timeout 10; then
  echo "[!] Reflector failed or timed out. Using curl fallback..."
  sudo curl -sSL -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/
  sudo sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
fi

# Step 4: Enable systemd services
echo -e "\n== Step 4: Enabling SystemD Networking =="
sudo systemctl enable NetworkManager.service || echo "[!] Could not enable NetworkManager"

# Step 5: Install Git and Curl if not present
echo -e "\n== Step 5: Installing Git and Curl (if missing) =="
sudo pacman -Sy --noconfirm git curl

# Step 6: Clone your repo
echo -e "\n== Step 6: Cloning your GitHub repo =="
rm -rf ArchSetup
if ! git clone https://github.com/Kaustub-Mocherla/Arch.git ArchSetup; then
  echo "[✗] Git clone failed. Check URL or internet."
  exit 1
fi

# Step 7: Set permissions and run inner script
echo -e "\n== Step 7: Setting permissions and running inner script =="
cd ArchSetup || exit 1
chmod +x install_celestia_arch.sh

if [[ -f install_celestia_arch.sh ]]; then
  ./install_celestia_arch.sh
else
  echo "[✗] install_celestia_arch.sh not found"
  exit 1
fi

echo -e "\n[✓] Done! If there were issues, scroll up and fix them manually."
