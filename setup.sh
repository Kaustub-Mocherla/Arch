# --- DIAG: what Caelestia expects vs. what you have ---

echo "[1] Check Caelestia config root:"
ls -la ~/.config/quickshell/caelestia || true

echo
echo "[2] List Caelestia modules you actually have:"
ls -1 ~/.config/quickshell/caelestia/modules || true

echo
echo "[3] Show first 25 lines of Background.qml to see its imports:"
nl -ba ~/.config/quickshell/caelestia/modules/background/Background.qml | sed -n '1,25p' || true

echo
echo "[4] Look for any 'qs.*' imports across the Caelestia modules:"
grep -RhoE '^import[[:space:]]+[^;]+' ~/.config/quickshell/caelestia/modules | sort -u || true

echo
echo "[5] Do we have a cached clone of the MAIN repo (not shell) with components/services/config)?"
ls -la ~/.cache/caelestia-src || true
ls -1 ~/.cache/caelestia-src/caelestia 2>/dev/null || true
ls -1 ~/.cache/caelestia-src/caelestia/modules 2>/dev/null || true

echo
echo "[6] Where are QuickShell’s system QML modules?"
echo "Expecting /usr/lib/qt6/qml/QuickShell/*"
ls -1 /usr/lib/qt6/qml/QuickShell 2>/dev/null || true