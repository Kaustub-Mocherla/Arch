# 1. Backup old mirrorlist (optional)
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

# 2. Use Reflector to fetch fresh mirrors (based on India; adjust if needed)
reflector --country India --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# 3. If the above doesn't work, fallback to default worldwide mirrors:
curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/

# 4. Uncomment all servers in the fallback list (make them usable)
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# 5. Now update pacman DB
pacman -Syy
