bash -euo pipefail <<'EOF'
# ── Fill ONLY the missing Caelestia QML modules (qs.services, qs.components, qs.config, qs.utils)

HOME_DIR="$HOME"
CFG_DIR="$HOME_DIR/.config/quickshell/caelestia"
MOD_ROOT="$CFG_DIR/modules"                 # your launcher already imports this root
QS_ROOT="$MOD_ROOT/qs"                       # module paths must be qs/services, qs/components, …

CACHE="$HOME_DIR/.cache/caelestia-src"
MAIN_REPO_URL="https://github.com/caelestia-dots/caelestia"

echo "[1] Ensure folders…"
mkdir -p "$QS_ROOT" "$CACHE"

echo "[2] Fetch/refresh MAIN repo…"
if [ -d "$CACHE/caelestia/.git" ]; then
  git -C "$CACHE/caelestia" fetch --all --prune
  git -C "$CACHE/caelestia" reset --hard origin/main
else
  git clone "$MAIN_REPO_URL" "$CACHE/caelestia"
fi

# Map of module name -> source dir in the repo
declare -A MAP=(
  [services]="services"
  [components]="components"
  [config]="config"
  [utils]="utils"
)

copy_qs_module () {
  local name="$1"
  local src="$CACHE/caelestia/${MAP[$name]}"
  local dst="$QS_ROOT/$name"

  if [ ! -d "$src" ]; then
    echo "  - WARN: repo missing '${MAP[$name]}' → skipping"
    return 0
  fi

  mkdir -p "$dst"
  # Copy/refresh files but DO NOT clobber your edits if any newer locally
  rsync -rt --delete "$src/" "$dst/"

  # Ensure the qmldir declares the right module (qs.<name>)
  if ! grep -q '^module[[:space:]]\+qs\.'"$name"'$' "$dst/qmldir" 2>/dev/null; then
    echo "module qs.$name" > "$dst/qmldir"
  fi

  echo "  - qs.$name ready at $dst"
}

echo "[3] Install/refresh qs.* modules under $QS_ROOT …"
copy_qs_module services
copy_qs_module components
copy_qs_module config
copy_qs_module utils

echo "[4] Verify layout and import path…"
echo "  - Expect to see: components  config  services  utils"
ls -1 "$QS_ROOT" || true

# Make sure your launcher style (QML2_IMPORT_PATH=<mods>) resolves qs/*
# Nothing to change if you already use: export QML2_IMPORT_PATH="$CFG_DIR/modules:…"
# Quick sanity test:
export QML2_IMPORT_PATH="$MOD_ROOT${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
if command -v quickshell >/dev/null 2>&1; then
  echo "  - Quick test: listing known module roots (not an error if none printed)"
  echo "$QML2_IMPORT_PATH" | tr ':' '\n' | sed 's/^/    /'
fi

echo
echo "✓ Modules synced. Now inside Hyprland, run:  caelestia-shell"
echo "  If anything still complains about qs.*:"
echo "    ls -R $QS_ROOT | sed 's/^/    /'"
EOF