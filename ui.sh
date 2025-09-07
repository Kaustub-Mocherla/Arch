#!/bin/bash

# Update system package database
sudo pacman -Syu --noconfirm

# Install required base-devel and git packages if not already installed
sudo pacman -S --needed base-devel git --noconfirm

# Install yay (AUR helper) if not installed
if ! command -v yay &> /dev/null
then
  git clone https://aur.archlinux.org/yay-git.git
  cd yay-git
  makepkg -si --noconfirm
  cd ..
  rm -rf yay-git
fi

# Use yay to install Google Chrome
yay -S --noconfirm google-chrome

# Use yay to install GitHub Desktop
yay -S --noconfirm github-desktop-bin

# Use yay to install Visual Studio Code
yay -S --noconfirm visual-studio-code-bin

# Optionally install yt-dlp for Youtube video downloading
sudo pacman -S --noconfirm yt-dlp
