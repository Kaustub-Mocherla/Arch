#!/usr/bin/env bash
# fix_caelestia.sh — reset & install Caelestia Shell cleanly
# Runs safely multiple times (idempotent).

set -euo pipefail

USER_HOME="${HOME}"
CFG_DIR="${USER_HOME}/.config/quickshell/caelestia"
MOD_DIR="${CFG_DIR}/modules"
LAUNCHER_DIR="${USER_HOME}/.local/bin"
LAUNCHER="${LAUNCHER_DIR}/caelestia-shell"
HYPR_CFG="${USER_HOME}/.config/hypr/hyprland.conf"
SHELL_REPO="https://github.com/caelestia-dots/shell"

say()  { printf "\033[1;36m[i]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[v]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[x]\033[0m %s\n" "$*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. Install it and re-run."
}

# --- 0) Quick sanity (we assume QuickShell is already installed) ---
need_cmd git
need_cmd curl
if ! command -v quickshell >/dev/null 2>&1; then
  warn "quickshell not found in PATH. If you have it as 'qs', that's fine."
  need_cmd qs
fi

# --- 1) Ensure PATH includes ~/.local/bin (for our launcher) ---
mkdir -p "${LAUNCHER_DIR}"
case ":${PATH}:" in
  *":${LAUNCHER_DIR}:"*) : ;;
  *)
    say "Adding ${LAUNCHER_DIR} to PATH via ~/.profile"
    touch "${USER_HOME}/.profile"
    if ! grep -q 'export PATH=.*\.local/bin' "${USER_HOME}/.profile"; then
      printf '\n# Add user bin to PATH for Caelestia launcher\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${USER_HOME}/.profile"
    fi
    ;;
esac

# --- 2) Remove any broken/old Caelestia config ---
if [ -e "${CFG_DIR}" ]; then
  say "Removing old Caelestia config at ${CFG_DIR}"
  rm -rf "${CFG_DIR}"
fi
mkdir -p "${CFG_DIR}"

# --- 3) Fetch Caelestia shell (git first, then zip fallback) ---
say "Cloning Caelestia Shell repo → ${CFG_DIR}"
if ! git clone --depth=1 "${SHELL_REPO}" "${CFG_DIR}" 2>/dev/null; then
  warn "git clone failed; trying tarball fallback"
  ZIP_URL="https://codeload.github.com/caelestia-dots/shell/zip/refs/heads/main"
  TMP_ZIP="$(mktemp)"
  curl -L "${ZIP_URL}" -o "${TMP_ZIP}" || die "Failed to download shell tarball."
  ( cd "$(dirname "${CFG_DIR}")"
    rm -rf shell-main
    unzip -q "${TMP_ZIP}" || die "unzip failed (not a gzip; that’s OK—this is a zip)."
    mv shell-main "${CFG_DIR}" )
  rm -f "${TMP_ZIP}"
fi
ok "Repo ready."

# --- 4) Verify required files ---
[ -f "${CFG_DIR}/shell.qml" ] || die "shell.qml missing in ${CFG_DIR}."
[ -d "${MOD_DIR}" ] || die "modules/ missing in ${CFG_DIR}."
ok "Found shell.qml and modules/."

# --- 5) Create the launcher (~/.local/bin/caelestia-shell) ---
say "Creating launcher ${LAUNCHER}"
cat > "${LAUNCHER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONF="$HOME/.config/quickshell/caelestia/shell.qml"
MODS="$HOME/.config/quickshell/caelestia/modules"

# Prefer Wayland; QuickShell will fall back if needed.
export QT_QPA_PLATFORM=wayland
# Make sure Caelestia's QML modules are found:
export QML2_IMPORT_PATH="${MODS}${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

# Some systems install QuickShell as 'qs' instead of 'quickshell'
if command -v quickshell >/dev/null 2>&1; then
  exec quickshell -c "$CONF"
else
  exec qs -c "$CONF"
fi
EOF
chmod +x "${LAUNCHER}"
ok "Launcher created."

# --- 6) (Optional) Autostart inside Hyprland ---
if [ -f "${HYPR_CFG}" ]; then
  if ! grep -q 'quickshell -c caeles' "${HYPR_CFG}" && ! grep -q 'caelestia-shell' "${HYPR_CFG}"; then
    say "Adding exec-once autostart to Hyprland config"
    printf '\n# Autostart Caelestia Shell\nexec-once = caelestia-shell\n' >> "${HYPR_CFG}"
  else
    warn "Hyprland autostart already present; leaving as-is."
  fi
else
  warn "Hyprland config not found at ${HYPR_CFG}; skipping autostart."
fi

# --- 7) Final checks & hint ---
ok "All set."
echo
echo "Run now (inside Hyprland/Wayland):   caelestia-shell"
echo "If 'command not found', reload PATH:  . ~/.profile"
echo
echo "Troubleshooting:"
echo "  • If you see 'Type Background/FileDialog … unavailable',"
echo "    it means QML modules weren’t found. This script fixes that by"
echo "    exporting QML2_IMPORT_PATH in the launcher. Always run 'caelestia-shell',"
echo "    not bare 'quickshell -c …'."