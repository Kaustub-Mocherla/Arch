#!/usr/bin/env bash
# Fix Caelestia UI not showing and autostart it in Hyprland
# - Adds exec-once for QuickShell (Caelestia shell.qml)
# - Creates hyprland.conf if missing (with a sane stub)
# - Backs up any file it edits (once)
# - Tries to pick a terminal (kitty/foot/alacritty) to start too
# - Reloads Hyprland if running, otherwise tells you what to do

set -Eeuo pipefail

# ---------- pretty prints ----------
C0="\033[0m"; Cg="\033[1;32m"; Cy="\033[1;33m"; Cr="\033[1;31m"; Cb="\033[1;34m"
ok(){   echo -e "${Cg}[✓]${C0} $*"; }
warn(){ echo -e "${Cy}[!]${C0} $*"; }
err(){  echo -e "${Cr}[x]${C0} $*"; }

# ---------- paths & probes ----------
HCONF_DIR="$HOME/.config/hypr"
HCONF="$HCONF_DIR/hyprland.conf"
QML="$HOME/.config/quickshell/caelestia/shell.qml"
QS_BIN="$(command -v qs || true)"
[ -z "$QS_BIN" ] && QS_BIN="$(command -v quickshell || true)"

# choose a terminal to autostart (best-effort, optional)
term=""
for c in kitty foot alacritty; do
  if command -v "$c" >/dev/null 2>&1; then term="$c"; break; fi
done

# ---------- checks ----------
if [ -z "$QS_BIN" ]; then
  warn "QuickShell binary not found (qs/quickshell)."
  warn "Install it first (e.g. 'yay -S quickshell-git') then re-run this script."
fi

if [ ! -f "$QML" ]; then
  warn "Caelestia shell QML not found at:"
  echo "     $QML"
  warn "If you haven’t installed Caelestia shell yet, do that first, or adjust path below."
fi

# ---------- prepare hyprland.conf ----------
mkdir -p "$HCONF_DIR"

if [ ! -f "$HCONF" ]; then
  warn "No hyprland.conf found; creating a minimal one."
  cat > "$HCONF" <<'HYPR'
# Minimal Hyprland config (created by fix_ui.sh)
# You can edit this later to your liking.

# Example monitor rule (Hyprland default usually works without this)
# monitor=,preferred,auto,auto

# Input defaults (optional)
# input {
#   kb_layout = us
# }

# The Caelestia QuickShell autostart block is appended below by fix_ui.sh
HYPR
  ok "Created $HCONF"
fi

# one-time backup
if [ ! -f "${HCONF}.bak.fixui" ]; then
  cp -n "$HCONF" "${HCONF}.bak.fixui" || true
  ok "Backup saved to ${HCONF}.bak.fixui"
fi

# Remove any old lines that tried to launch quickshell/qs to avoid duplicates
sed -i '/exec-once\s*=\s*.*\(quickshell\|^qs\| qs \)/d' "$HCONF"

# Compose the autostart block
QS_CMD="\$${RANDOM}"  # dummy; we set real cmd below
if [ -n "$QS_BIN" ]; then
  QS_CMD="$QS_BIN -c $QML"
else
  # still write a placeholder so user sees what to change
  QS_CMD="quickshell -c $QML"
fi

# Optional wallpaper starter (commented out, safe to enable)
WALL_LINE="# exec-once = swww init && swww img ~/Pictures/wallpapers/mywall.png"

# Optional terminal starter (only if we found one)
TERM_LINE=""
[ -n "$term" ] && TERM_LINE="exec-once = $term"

cat >> "$HCONF" <<EOF

# === Added by fix_ui.sh (Caelestia QuickShell autostart) ===
# If this block misbehaves, check your QuickShell binary and QML path.
exec-once = $QS_CMD
$TERM_LINE
$WALL_LINE
# === end block ===
EOF

ok "Wrote QuickShell autostart to $HCONF"
[ -n "$term" ] && ok "Terminal will autostart: $term" || warn "No terminal found to autostart (kitty/foot/alacritty)."

# ---------- try a live reload ----------
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  if hyprctl reload >/dev/null 2>&1; then
    ok "Hyprland reloaded. Give it a second — Caelestia UI should appear."
  else
    warn "Tried to reload Hyprland but failed. Log out and log back in."
  fi
else
  warn "Hyprland not detected as running from this shell."
  echo "  -> Log out to tty and run:  hyprland   (or reboot into your Hyprland session)."
fi

# ---------- final hints ----------
echo
[ -z "$QS_BIN" ] && warn "Install QuickShell (qs) and re-run this script."
[ ! -f "$QML" ]  && warn "Ensure Caelestia QML exists at: $QML"
echo
ok "Done."