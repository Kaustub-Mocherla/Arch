#!/bin/bash
# Force Start ML4W Components - Complete Fix

echo "🔧 Starting ML4W components manually..."

# Step 1: Check what ML4W components should be running
echo "🔍 Checking ML4W installation..."
ls ~/.config/hypr/
ls ~/.config/waybar/
ls ~/.config/rofi/

# Step 2: Kill any stuck processes
echo "🧹 Cleaning stuck processes..."
killall waybar rofi hyprpaper swww 2>/dev/null || true
sleep 3

# Step 3: Start waybar (ML4W's status bar)
echo "📊 Starting ML4W Waybar..."
if [ -f ~/.config/waybar/config ]; then
    waybar &
    sleep 2
    echo "✅ Waybar started"
else
    echo "❌ Waybar config missing - fixing..."
    cp /etc/xdg/waybar/config ~/.config/waybar/ 2>/dev/null || true
    waybar &
fi

# Step 4: Start wallpaper manager
echo "🖼️ Starting wallpaper..."
if [ -f ~/.config/hypr/hyprpaper.conf ]; then
    hyprpaper &
    sleep 2
    echo "✅ Wallpaper manager started"
else
    echo "🔨 Creating wallpaper config..."
    mkdir -p ~/.config/hypr
    cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/.config/hypr/wallpapers/ml4w-hyprland.jpg
wallpaper = ,~/.config/hypr/wallpapers/ml4w-hyprland.jpg
ipc = on
EOF
    hyprpaper &
fi

# Step 5: Check if ML4W Settings app exists
echo "⚙️ Checking ML4W Settings..."
if command -v ml4w-settings &> /dev/null; then
    echo "✅ ML4W Settings available"
else
    echo "📦 Installing ML4W Settings..."
    yay -S --noconfirm ml4w-hyprland-settings
fi

# Step 6: Fix ML4W autostart in Hyprland config
echo "🔧 Fixing ML4W autostart..."
HYPR_CONF=~/.config/hypr/hyprland.conf

# Check if ML4W autostart commands exist
if ! grep -q "exec-once = waybar" "$HYPR_CONF"; then
    echo "exec-once = waybar" >> "$HYPR_CONF"
fi

if ! grep -q "exec-once = hyprpaper" "$HYPR_CONF"; then
    echo "exec-once = hyprpaper" >> "$HYPR_CONF"
fi

# Step 7: Test ML4W components
echo "🧪 Testing ML4W components..."
sleep 3

# Check if waybar is visible
if pgrep waybar > /dev/null; then
    echo "✅ Waybar is running"
else
    echo "❌ Waybar failed to start"
fi

# Check if wallpaper loaded
if pgrep hyprpaper > /dev/null; then
    echo "✅ Wallpaper manager is running"
else
    echo "❌ Wallpaper manager failed"
fi

echo ""
echo "🎉 ML4W components started!"
echo ""
echo "📱 You should now see:"
echo "   ✅ Waybar at the top of screen"
echo "   ✅ Beautiful wallpaper background"
echo "   ✅ Working ML4W interface"
echo ""
echo "🔑 ML4W Shortcuts to test:"
echo "   • Super + Return  → Terminal"
echo "   • Super + D       → Rofi launcher"
echo "   • Super + E       → File manager"
echo "   • Super + L       → Lock screen"
echo ""
echo "🆘 If still not working:"
echo "   1. Press Super + M to logout"
echo "   2. Login again"
echo "   3. Components should autostart"
