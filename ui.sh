bash -euo pipefail <<'EOF'
echo "== Caelestia: clean old install and run via Nix =="

# --- 0) Sanity: need nix
if ! command -v nix >/dev/null 2>&1; then
  echo "!! nix is not installed. Install Nix first, then re-run."
  exit 1
fi

# --- 1) Stop any running quickshell/caelestia
echo "[1/6] Stopping running quickshell sessions (if any)…"
pkill -x quickshell 2>/dev/null || true
sleep 0.5

# --- 2) Backup + remove old mixed install
echo "[2/6] Backing up and removing previous Caelestia files…"
TS="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/caelestia-backup-$TS"
mkdir -p "$BK"

# Move (backup) if present
for P in \
  "$HOME/.config/quickshell/caelestia" \
  "$HOME/.cache/caelestia-src" \
  "$HOME/.local/bin/caelestia-shell"
do
  if [ -e "$P" ]; then
    echo "  ↳ backing up: $P -> $BK/"
    mv "$P" "$BK/" || true
  fi
done

# --- 3) Ensure Nix experimental features (flakes + nix-command)
echo "[3/6] Ensuring Nix experimental features enabled…"
mkdir -p "$HOME/.config/nix"
NIXCONF="$HOME/.config/nix/nix.conf"
touch "$NIXCONF"
if ! grep -q '^experimental-features.*flakes' "$NIXCONF" 2>/dev/null; then
  printf '%s\n' 'experimental-features = nix-command flakes' >> "$NIXCONF"
  echo "  ↳ wrote: experimental-features = nix-command flakes"
else
  echo "  ↳ already enabled."
fi

# --- 4) Optional: make sure swww daemon is ready for wallpapers (no-op if present)
echo "[4/6] Ensuring swww daemon (Wayland wallpaper) is running…"
if command -v swww >/dev/null 2>&1; then
  pgrep -x swww-daemon >/dev/null 2>&1 || swww init || true
else
  echo "  (swww not installed system-wide; Caelestia can still run under Nix)"
fi

# --- 5) Run Caelestia via Nix (pure source of truth)
echo "[5/6] Launching Caelestia from Nix…"
# Use env override too, in case user’s nix.conf wasn’t picked up yet in this session
NIX_CONFIG="experimental-features = nix-command flakes" \
nix run github:caelestia-dots/shell

# --- 6) Notes
echo "[6/6] Done."
echo
echo "If you want to launch again later, just run:"
echo "  nix run github:caelestia-dots/shell"
echo
echo "Your old files were backed up at: $BK"
EOF