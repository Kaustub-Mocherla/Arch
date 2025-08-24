#!/bin/bash

set -e

echo "[*] Starting full Arch setup..."

# Step 1: Fix mirrors (handles timeout, slow repo errors)
echo "[*] Updating mirrorlist with fastest servers..."
sudo pacman -Sy --noconfirm reflector || sudo pacman -Sy --noconfirm
sudo reflector --country India --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || {
    echo "[!] Reflector failed, falling back to curl method..."
    sudo curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/
    sudo sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
}

# Step 2: Update system and keys
echo "[*] Syncing and updating system..."
sudo pacman -Syyu --noconfirm || echo "[!] Pacman update failed, retry manually later."

# Step 3: Ensure internet is up
ping -c 3 archlinux.org >/dev/null || {
    echo "[!] Network check failed. Try connecting to WiFi first."
    exit 1
}

# Step 4: Ensure NetworkManager is installed and active
echo "[*] Checking NetworkManager..."
if ! command -v nmcli &> /dev/null; then
    echo "[*] Installing NetworkManager..."
    sudo pacman -S --noconfirm networkmanager
fi
sudo systemctl enable --now NetworkManager || echo "[!] Could not start NetworkManager. Check manually."

# Step 5: Install git and curl if not present
echo "[*] Ensuring git and curl are available..."
sudo pacman -S --noconfirm git curl

# Step 6: Clone your repo (replace with your username/repo if needed)
echo "[*] Cloning your repo..."
cd ~
rm -rf ArchSetup || true
git clone https://github.com/Kaustub-Mocherla/Arch.git ArchSetup || {
    echo "[!] Git clone failed. Check URL or network."
    exit 1
}

cd ArchSetup

# Step 7: Set permissions and run your script
if [[ -f install_coolest_arch.sh ]]; then
    chmod +x install_coolest_arch.sh
    echo "[*] Running your script: install_coolest_arch.sh"
    ./install_coolest_arch.sh || echo "[!] Your script had some errors. Check above logs."
else
    echo "[!] Script install_coolest_arch.sh not found!"
fi

echo "[✓] Done. If there were issues, scroll up and fix manually."
