#!/bin/bash
# Correct ML4W Installation - Based on Official Video Guide

echo "🔥 Installing ML4W Dotfiles - Correct Method"

# Stop display manager
sudo systemctl stop sddm || true

# Complete cleanup
rm -rf ~/.config ~/.local ~/.cache ~/Downloads/*
sudo pacman -Scc --noconfirm || true

# System update
sudo pacman -Syu --noconfirm

# Install base packages (exactly as shown in video)
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip
sudo pacman -S --needed --noconfirm hyprland kitty vim flatpak firefox waybar wofi

# Install yay (thermal protection)
if ! command -v yay &>/dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    MAKEFLAGS="-j1" makepkg -si --noconfirm
    cd ~ && rm -rf /tmp/yay
fi

# Add Flatpak repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install ML4W Dotfiles Installer (the correct way from video)
flatpak install -y flathub com.ml4w.dotfilesinstaller

# Enable SDDM
sudo systemctl enable sddm.service
sudo systemctl start sddm.service

echo ""
echo "🎉 ML4W Dotfiles Installer installed!"
echo ""
echo "📋 Next steps (as shown in video):"
echo "1. Reboot: sudo reboot"
echo "2. Login to Hyprland session"
echo "3. Open terminal: Super + Q"
echo "4. Run: flatpak run com.ml4w.dotfilesinstaller"
echo "5. Use URL: https://github.com/mylinuxforwork/dotfiles"
echo "6. Follow the installer GUI to complete setup"
echo ""
echo "🎯 This is the official method from your reference video!"

read -p "Reboot now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo reboot
fi
