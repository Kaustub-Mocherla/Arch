# 1. Set working mirrors
echo 'Server = https://mirror.i3d.net/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

# 2. Update packages
pacman -Sy

# 3. Install Git if not available
pacman -S --noconfirm git

# 4. Clone your public repo
cd ~
rm -rf Arch
git clone https://github.com/Kaustub-Mocherla/Arch.git
cd Arch

# 5. Run your installer
chmod +x install.sh
./install.sh
