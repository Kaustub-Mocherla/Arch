#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/dots-hyprland"
TARGET="$HOME/.config"
BACKUP="$HOME/.config_end4_conflict_backup_$(date +%F_%H%M%S)"

mkdir -p "$BACKUP"

echo "==> Checking for conflicts in ~/.config (fish, foot, hypr)"
for dir in fish foot hypr; do
    if [[ -e "$TARGET/$dir" && ! -d "$TARGET/$dir" ]]; then
        echo "⚠️  Found file instead of directory: $TARGET/$dir"
        echo "   Backing it up to: $BACKUP/"
        mv "$TARGET/$dir" "$BACKUP/"
    elif [[ -d "$TARGET/$dir" ]]; then
        echo "📦 Existing directory found: $TARGET/$dir"
        echo "   Backing it up completely to: $BACKUP/"
        mv "$TARGET/$dir" "$BACKUP/"
    fi
done

echo "==> Copying fresh configs from $REPO_DIR/.config to ~/.config"
cp -r "$REPO_DIR/.config/"* "$TARGET/"

echo
echo "✅ End-4 configs installed successfully!"
echo "   Backup of old configs: $BACKUP"