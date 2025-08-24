
#!/usr/bin/env bash

# Step 1: Download latest mirrorlist
sudo curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/

# Step 2: Uncomment all Server lines (use correct sed syntax!)
sudo sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# Step 3: Sync package databases
sudo pacman -Syy

# Caelestia Shell one-shot installer for Arch Linux (with mirror auto-fix)
set -euo pipefail
log(){ printf "\n\033[1;32m[+]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[!]\033[0m %s\n" "$*"; }
die(){ printf "\n\033[1;31m[x]\033[0m %s\n" "$*"; exit 1; }

[[ -f /etc/arch-release ]] || die "This script is for Arch Linux."
[[ $EUID -ne 0 ]] || die "Run as a normal user (uses sudo)."
command -v sudo >/dev/null || die "sudo is required."

P="--noconfirm --needed"
Y="--noconfirm --needed --answerdiff None --answerclean None"

# ---------------------------------------------------------------------------
# 0) MIRRORLIST AUTO-FIX (no editor required)
# ---------------------------------------------------------------------------
log "Refreshing Arch
