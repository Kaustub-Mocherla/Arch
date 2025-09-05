#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/dots-hyprland"
TARGET="$HOME/.config"
BACKUP="$HOME/.config_end4_conflict_backup_$(date +%F_%H%M%S)"

mkdir -p "$BACKUP"

echo "==> Fixing config copy conflicts"
for dir in fish foot hypr; do
    if [[ -e "$TARGET/$dir" && ! -d "$TARGET/$dir" ]]; then
        echo "Backing up conflicting file: $TARGET/$dir"
        mv "$TARGET/$dir" "$BACKUP/"
    fi
done

echo "==> Copying repo configs into ~/.config/"
cp -rT "$REPO_DIR/.config" "$TARGET"

echo
echo "✅ Configs installed successfully!"
echo "• Backup of conflicts: $BACKUP"