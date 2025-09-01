#!/usr/bin/env bash
# caelestia-doctor.sh — audit & optional repair for Caelestia + QuickShell
# Usage:
#   bash caelestia-doctor.sh          # audit only
#   bash caelestia-doctor.sh --fix    # apply common fixes (safe; uses symlinks)

set -euo pipefail

FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

say() { printf "%b\n" "$*"; }
hdr() { printf "\n\033[1;36m== %s ==\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; }
action(){ printf "\033[1;35m[ACTION]\033[0m %s\n" "$*"; }

USER_HOME="$HOME"
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
SYS_QML="/usr/lib/qt6/qml"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/caelestia-shell"

MISSING=()

hdr "System & versions"
uname -a || true
if command -v quickshell >/dev/null 2>&1; then
  quickshell --version || true
else
  err "quickshell not on PATH"; MISSING+=("quickshell")
fi
if command -v caelestia >/dev/null 2>&1; then
  caelestia --version || true
else
  warn "caelestia CLI not on PATH (some features use it)"
fi

hdr "Core binaries"
need_bins=(playerctl pamixer brightnessctl swww wl-copy grim slurp swappy curl jq rsync)
for b in "${need_bins[@]}"; do
  if command -v "$b" >/dev/null 2>&1; then ok "$b"; else warn "$b missing"; MISSING+=("$b"); fi
done

hdr "Qt/QML directories"
if [[ -d "$SYS_QML" ]]; then
  ok "System QML dir: $SYS_QML"
  # Spot-check QuickShell QML modules
  for d in Quickshell Quickshell/Services Quickshell/Hyprland Quickshell/Wayland; do
    [[ -d "$SYS_QML/$d" ]] && ok "present: $d" || warn "missing: $SYS_QML/$d"
  done
else
  err "System QML dir not found: $SYS_QML"
fi

hdr "Caelestia config directory"
if [[ -d "$CE_DIR" ]]; then
  ok "Found: $CE_DIR"
else
  err "Caelestia directory missing: $CE_DIR"
  say "If you used cmake with -DINSTALL_QSCONFDIR, install target should have populated it."
fi

say "Tree (depth 2):"
find "$CE_DIR" -maxdepth 2 -type d -printf "  %p\n" 2>/dev/null || true

[[ -f "$CE_DIR/shell.qml" ]] && ok "shell.qml present" || { err "shell.qml missing"; MISSING+=("shell.qml"); }

hdr "Launcher sanity ($LAUNCHER)"
if [[ -x "$LAUNCHER" ]]; then
  ok "launcher exists"
  if grep -q 'QML2_IMPORT_PATH' "$LAUNCHER"; then
    ok "launcher exports QML2_IMPORT_PATH"
  else
    warn "launcher does not export QML2_IMPORT_PATH"
    [[ $FIX -eq 1 ]] && action "Will rewrite launcher to export QML2_IMPORT_PATH"
  fi
else
  warn "launcher missing at $LAUNCHER"
  [[ $FIX -eq 1 ]] && action "Will create launcher"
fi

hdr "Environment (current shell)"
say "QML2_IMPORT_PATH=${QML2_IMPORT_PATH:-<unset>}"
say "QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-<unset>}"

hdr "Expected Caelestia module layout"
# Caelestia shell may ship either:
#  - root dirs: $CE_DIR/{components,services,config,utils}
#  - nested:   $CE_DIR/modules/qs/{components,services,config,utils}
root_ok=1
qs_ok=1
for d in components services config utils; do
  [[ -d "$CE_DIR/$d" ]] || root_ok=0
  [[ -d "$CE_DIR/modules/qs/$d" ]] || qs_ok=0
done

if [[ $root_ok -eq 1 ]]; then ok "root-style modules present (components/services/config/utils)"; fi
if [[ $qs_ok   -eq 1 ]]; then ok "qs-style modules present under modules/qs/*"; fi
if [[ $root_ok -eq 0 && $qs_ok -eq 0 ]]; then
  err "Neither root nor modules/qs layout found — Caelestia modules missing"
fi

hdr "QML import scan (looking for qs.*)"
imports=()
if [[ -f "$CE_DIR/shell.qml" ]]; then
  mapfile -t imports < <(grep -hEo 'import[[:space:]]+qs\.[A-Za-z]+' "$CE_DIR"/{shell.qml,**/*.qml} 2>/dev/null \
                         | awk '{print $2}' | sort -u)
fi

if ((${#imports[@]})); then
  for imp in "${imports[@]}"; do
    mod="${imp#qs.}" # e.g., services
    # Resolvable if either modules/qs/<mod> or <mod> exists
    if [[ -d "$CE_DIR/modules/qs/$mod" || -d "$CE_DIR/$mod" ]]; then
      ok "import $imp -> found"
    else
      err "import $imp -> NOT found"
      MISSING+=("$imp")
    fi
  done
else
  warn "No qs.* imports found in scan (shell.qml may include them indirectly)."
fi

hdr "Wallpaper status"
if pgrep -x swww-daemon >/dev/null 2>&1; then ok "swww-daemon running"; else warn "swww-daemon not running"; fi

# ----------------------- FIXUPS -----------------------
if [[ $FIX -eq 1 ]]; then
  hdr "Applying fixes"

  # 1) Create modules/qs shim via symlinks if only root layout exists
  if [[ $root_ok -eq 1 && $qs_ok -eq 0 ]]; then
    action "Creating modules/qs/* symlinks pointing to root dirs"
    mkdir -p "$CE_DIR/modules/qs"
    for d in components services config utils; do
      if [[ -d "$CE_DIR/$d" && ! -e "$CE_DIR/modules/qs/$d" ]]; then
        ln -s "../../$d" "$CE_DIR/modules/qs/$d"
        ok "linked modules/qs/$d -> ../../$d"
      fi
    done
    qs_ok=1
  fi

  # 2) Rewrite/create launcher with robust import path
  if [[ ! -x "$LAUNCHER" ]] || ! grep -q 'QML2_IMPORT_PATH' "$LAUNCHER"; then
    action "Writing launcher $LAUNCHER"
    mkdir -p "$BIN_DIR"
    cat > "$LAUNCHER" <<'LAU'
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
SYS_QML="/usr/lib/qt6/qml"
# Include both Caelestia root + modules/qs + system QML
export QML2_IMPORT_PATH="$CE_DIR:$CE_DIR/modules:$CE_DIR/modules/qs:$SYS_QML${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_QPA_PLATFORM=wayland
if command -v caelestia >/dev/null 2>&1; then
  exec caelestia shell -d
else
  exec quickshell -c "$CE_DIR"
fi
LAU
    chmod +x "$LAUNCHER"
    ok "launcher updated"
  fi

  # 3) Start swww if missing and try a first wallpaper
  if ! pgrep -x swww-daemon >/dev/null 2>&1; then
    action "Starting swww-daemon"
    swww init || true
  fi
  if command -v swww >/dev/null 2>&1; then
    if ! swww query >/dev/null 2>&1; then
      # pick a candidate image
      for d in "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME"; do
        CAND="$(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -n1 || true)"
        [[ -n "${CAND:-}" ]] && { action "Setting wallpaper: $CAND"; swww img "$CAND" --transition-type any || true; break; }
      done
    fi
  fi

  ok "Fixes applied."
fi

hdr "Diagnosis summary"
if ((${#MISSING[@]})); then
  printf "%s\n" "Items flagged:"; printf "  - %s\n" "${MISSING[@]}"
else
  ok "No obvious missing pieces detected."
fi

echo
say "Next step:"
say "  • Launch:  caelestia-shell"
say "  • If it still looks bare, run and paste first 30 lines of output:"
say "        quickshell -c \"$CE_DIR\" 2>&1 | sed -n '1,200p' | head -n 50"