#!/bin/bash
# Complete Sugar Candy SDDM Theme + NumLock + Shortcuts Setup

echo "🍭 Setting up Sugar Candy SDDM theme with NumLock disabled and Super key shortcuts"

# Step 1: Install Sugar Candy theme
echo "📦 Installing Sugar Candy theme..."
yay -S sddm-sugar-candy-git

# Step 2: Install required Qt5 dependencies
sudo pacman -S --needed qt5-graphicaleffects qt5-quickcontrols2 qt5-svg

# Step 3: Configure SDDM with Sugar Candy theme and NumLock OFF
echo "⚙️ Configuring SDDM..."
sudo tee /etc/sddm.conf << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=off

[Theme]
Current=sugar-candy

[Users]
MaximumUid=60513
MinimumUid=1000
EOF

# Step 4: Create NumLock configuration (more reliable method)
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/numlock.conf << 'EOF'
[General]
Numlock=off
EOF

# Step 5: Fix potential Sugar Candy login issues
sudo sed -i 's/AllowBadUsernames="false"/AllowBadUsernames="true"/' /usr/share/sddm/themes/sugar-candy/theme.conf 2>/dev/null || true

# Step 6: Add ML4W-compatible keybindings to Hyprland config
echo "⌨️ Adding Super key shortcuts to Hyprland..."
cat >> ~/.config/hypr/hyprland.conf << 'EOF'

# ========== ML4W-Compatible Super Key Shortcuts ==========
$mainMod = SUPER

# Essential shortcuts (from ML4W defaults)
bind = $mainMod, RETURN, exec, kitty                    # Terminal
bind = $mainMod, B, exec, firefox                       # Browser
bind = $mainMod CTRL, RETURN, exec, wofi --show drun    # App launcher
bind = $mainMod, E, exec, dolphin                       # File manager
bind = $mainMod, Q, killactive                          # Close window
bind = $mainMod, M, exit                                 # Logout
bind = $mainMod, T, togglefloating                      # Toggle floating
bind = $mainMod, F, fullscreen                          # Fullscreen

# Screenshots
bind = $mainMod, PRINT, exec, grim -g "$(slurp)" - | wl-copy  # Screenshot

# ML4W specific shortcuts
bind = $mainMod SHIFT, W, exec, ~/dotfiles/scripts/wallpaper.sh        # Change wallpaper
bind = $mainMod CTRL, Q, exec, ~/dotfiles/scripts/power-menu.sh        # Logout screen
bind = $mainMod CTRL, S, exec, ~/dotfiles/scripts/settings.sh          # Settings
bind = $mainMod SHIFT, B, exec, ~/dotfiles/scripts/reload-waybar.sh    # Reload waybar

# Workspaces (ML4W default: 1-5)
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

# Move windows to workspaces
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow    # Move window with Super + Left click
bindm = $mainMod, mouse:273, resizewindow  # Resize window with Super + Right click

EOF

echo "✅ Configuration complete!"
echo ""
echo "🎯 What's been configured:"
echo "   ✅ Sugar Candy SDDM theme installed"
echo "   ✅ NumLock disabled on login screen"
echo "   ✅ ML4W-compatible Super key shortcuts added"
echo ""
echo "🔑 Your new Super key shortcuts:"
echo "   • Super + Enter → Terminal"
echo "   • Super + B → Firefox browser"
echo "   • Super + Ctrl + Enter → App launcher"
echo "   • Super + E → File manager"
echo "   • Super + Q → Close window"
echo "   • Super + M → Logout"
echo "   • Super + 1-5 → Switch workspaces"
echo "   • Super + Shift + 1-5 → Move window to workspace"
echo "   • Super + Left/Right mouse → Move/resize windows"
echo ""
echo "🔄 To apply all changes:"
echo "   1. Reload Hyprland: Super + Shift + R"
echo "   2. Or logout and login again"
echo ""
echo "🎨 Sugar Candy theme features:"
echo "   • Modern Material Design login screen"
echo "   • Blur effects and smooth animations"
echo "   • NumLock stays OFF at login"
echo "   • Matches your beautiful ML4W desktop"

# Test the theme (optional)
read -p "🔍 Test Sugar Candy theme now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧪 Testing theme..."
    sddm-greeter --test-mode --theme /usr/share/sddm/themes/sugar-candy &
    echo "💡 Close the test window when ready"
fi

echo ""
echo "🍭 Sugar Candy setup complete! Logout to see your new login screen."
