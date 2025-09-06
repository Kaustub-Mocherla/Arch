# Fix ownership of config directories
sudo chown -R $USER:$USER ~/.config/
chmod -R 755 ~/.config/

# Create missing directories with proper permissions
mkdir -p ~/.config/hypr/{scripts,wallpapers}
mkdir -p ~/.local/share/applications
mkdir -p ~/.cache/hyprland
