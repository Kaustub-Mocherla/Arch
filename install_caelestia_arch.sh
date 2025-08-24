#!/bin/bash
set -e

echo -e "\n== Arch Linux Installer: Custom Setup =="

### Step 1: Check Internet Connection
echo -e "\n== Step 1: Checking Internet Connectivity =="
if ping -c 1 archlinux.org &>/dev/null; then
    echo "[✓] Internet is working."
else
    echo "[✗] Internet not working. Please check Wi-Fi or Ethernet connection."
    exit 1
fi

### Step 2: Install Essential Tools
echo -e "\n== Step 2: Installing Git and Curl =="
sudo pacman -Sy --noconfirm git curl || {
    echo "[✗] Failed to install git/curl. Retrying with fixed mirror."
    sudo bash -c 'echo "Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist'
    sudo pacman -Syy --noconfirm git curl || {
        echo "[✗] Still failed to install essential tools. Exiting."
        exit 1
    }
}

### Step 3: Set Known Working Mirror (skip reflector)
echo -e "\n== Step 3: Setting working mirror =="
sudo bash -c 'cat > /etc/pacman.d/mirrorlist <<EOF
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
EOF'

### Step 4: Initialize pacman
echo -e "\n== Step 4: Initializing pacman keys =="
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syy --noconfirm

### Step 5: Enable networking service
echo -e "\n== Step 5: Enabling NetworkManager (if available) =="
if systemctl list-unit-files | grep -q NetworkManager.service; then
    sudo systemctl enable NetworkManager.service
else
    echo "[!] NetworkManager not installed. Skipping enable step."
fi

### Step 6: Clone GitHub repo
echo -e "\n== Step 6: Cloning your Arch setup repo =="
rm -rf ArchSetup
git clone https://github.com/Kaustub-Mocherla/Arch.git ArchSetup || {
    echo "[✗] Git clone failed. Please verify the repo URL and internet."
    exit 1
}

### Step 7: Run internal install script
echo -e "\n== Step 7: Running the internal install script =="
cd ArchSetup

if [[ -f install_celestia_arch.sh ]]; then
    chmod +x install_celestia_arch.sh
    ./install_celestia_arch.sh || {
        echo "[✗] Internal script failed. Check the logs above."
        exit 1
    }
else
    echo "[✗] 'install_celestia_arch.sh' not found in the repo!"
    exit 1
fi

echo -e "\n[✓] Installation script completed successfully!"
