echo "== quickshell version"; quickshell --version
echo
echo "== quickshell binary"; command -v quickshell
echo
echo "== Caelestia config dir"; ls -al "$HOME/.config/quickshell/caelestia"
echo
echo "== first lines of shell.qml"; head -n 5 "$HOME/.config/quickshell/caelestia/shell.qml"
echo
echo "== QML2_IMPORT_PATH env"; printf '%s\n' "${QML2_IMPORT_PATH:-<empty>}"
echo
echo "== QuickShell package files (note: -Ql uses a *lowercase* L)"
pacman -Ql quickshell | awk '{print $2}' | grep -E '/(qml|modules)/?$' | sed -n '1,30p'
echo
echo "== Search filesystem for quickshell QML dirs (may take a few seconds)"
find /usr -maxdepth 6 -type d \( -iname '*quickshell*' -o -ipath '*/qt6/qml/*' \) 2>/dev/null | sed -n '1,50p'
echo
echo "== launcher content (if present)"; grep -n 'QML2_IMPORT_PATH\|quickshell -c' "$HOME/.local/bin/caelestia-shell" || echo "(no launcher)"