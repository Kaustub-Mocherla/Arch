#!/usr/bin/env bash
# setup_stocks.sh — one-shot installer for a tiny stocks widget command
# Usage:
#   ./setup_stocks.sh            # install command only
#   ./setup_stocks.sh --timer    # also install a systemd --user timer that refreshes a cache file
#   ./setup_stocks.sh --force    # recreate files/venv even if present
set -euo pipefail

want_timer=0
force=0
for a in "$@"; do
  case "$a" in
    --timer) want_timer=1 ;;
    --force) force=1 ;;
    -h|--help)
      echo "Usage: $0 [--timer] [--force]"
      exit 0
      ;;
    *) echo "[!] Unknown flag: $a" >&2; exit 1 ;;
  esac
done

# ---- paths (per-user) ----
USER_HOME="${HOME}"
BIN_DIR="$USER_HOME/.local/bin"
DATA_DIR="$USER_HOME/.local/share/caelestia-stocks"
CONF_DIR="$USER_HOME/.config/caelestia"
VENV="$DATA_DIR/venv"
LAUNCHER="$BIN_DIR/caelestia-stocks"
TICKERS="$CONF_DIR/stocks.txt"
CACHE="$DATA_DIR/last.txt"

SERVICE_DIR="$USER_HOME/.config/systemd/user"
SRV="$SERVICE_DIR/caelestia-stocks.service"
TMR="$SERVICE_DIR/caelestia-stocks.timer"

# ---- helpers ----
have() { command -v "$1" >/dev/null 2>&1; }
ok()   { printf "\033[32m[✓]\033[0m %s\n" "$*"; }
info() { printf "\033[36m[i]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[31m[x]\033[0m %s\n" "$*" >&2; }

# ---- sanity: prefer running as your normal user ----
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  warn "You're running as root. This script installs to the CURRENT user's home."
  warn "If you want it for your normal account, run this as that user (not sudo)."
fi

# ---- ensure Python & tools (Arch) ----
if ! have python || ! python -c 'import venv' 2>/dev/null || ! have pip; then
  info "Installing python, python-venv, python-pip (requires sudo)…"
  if ! have sudo; then
    err "sudo not found. Install sudo or run: pacman -S python python-venv python-pip"
    exit 1
  fi
  sudo pacman -Sy --noconfirm --needed python python-venv python-pip || {
    err "Failed to install Python packages."; exit 1; }
else
  ok "Python + venv + pip already present."
fi

# ---- create dirs ----
mkdir -p "$BIN_DIR" "$DATA_DIR" "$CONF_DIR"

# ---- create / refresh venv ----
if [[ ! -d "$VENV" || $force -eq 1 ]]; then
  info "Creating virtualenv at $VENV…"
  rm -rf "$VENV"
  python -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip >/dev/null
  "$VENV/bin/pip" install --upgrade yfinance >/dev/null
  ok "venv ready with yfinance."
else
  ok "venv already exists."
  # make sure yfinance is there
  if ! "$VENV/bin/python" -c 'import yfinance' 2>/dev/null; then
    info "Installing yfinance into venv…"
    "$VENV/bin/pip" install --upgrade yfinance >/dev/null
  fi
fi

# ---- create tickers file (first-time) ----
if [[ ! -s "$TICKERS" || $force -eq 1 ]]; then
  info "Writing default tickers to $TICKERS"
  cat >"$TICKERS" <<'EOF'
# One ticker per line. NSE uses .NS suffix.
INFY.NS
TCS.NS
AAPL
# Add more lines as you like…
EOF
fi

# ---- write the launcher command ----
if [[ ! -f "$LAUNCHER" || $force -eq 1 ]]; then
  info "Installing $LAUNCHER"
  cat >"$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
VENV="$HOME/.local/share/caelestia-stocks/venv"
PY="$VENV/bin/python"
CFG="$HOME/.config/caelestia/stocks.txt"
CACHE="$HOME/.local/share/caelestia-stocks/last.txt"

# Fast path: print cache if --cached requested (for panels that poll often)
if [[ "${1:-}" == "--cached" && -s "$CACHE" ]]; then
  cat "$CACHE"; exit 0
fi

if [[ ! -x "$PY" ]]; then
  echo "[x] venv missing at $VENV" >&2; exit 1
fi
if [[ ! -s "$CFG" ]]; then
  echo "[x] No tickers file at $CFG" >&2; exit 1
fi

OUT="$("$PY" - <<'PYEOF'
import os, sys
cfg = os.path.expanduser("~/.config/caelestia/stocks.txt")
with open(cfg) as f:
    tickers=[l.strip() for l in f if l.strip() and not l.lstrip().startswith('#')]

try:
    import yfinance as yf
except Exception:
    print("[x] yfinance not installed", file=sys.stderr); sys.exit(1)

parts=[]
for s in tickers[:10]:
    try:
        t = yf.Ticker(s).fast_info
        price = float(t.get('last_price') or 0.0)
        prev  = t.get('regular_market_previous_close') or t.get('previous_close') or 0.0
        ch = (0.0 if not prev else (price - float(prev)) / float(prev) * 100.0)
        arrow = '▲' if ch >= 0 else '▼'
        parts.append(f"{s} {price:.2f} {arrow}{abs(ch):.2f}%")
    except Exception:
        parts.append(f"{s} ?")
print(" | ".join(parts))
PYEOF
)"; CODE=$?

# If success, refresh cache
if [[ $CODE -eq 0 ]]; then
  mkdir -p "$(dirname "$CACHE")"
  printf "%s\n" "$OUT" > "$CACHE"
fi

printf "%s\n" "$OUT"
exit $CODE
EOF
  chmod +x "$LAUNCHER"
fi
ok "Command installed: $LAUNCHER"

# ---- ensure ~/.local/bin on PATH for Bash/Zsh/Fish ----
shell_name="$(basename "${SHELL:-}")"
case "$shell_name" in
  bash)
    if ! grep -q 'HOME/.local/bin' "$USER_HOME/.bashrc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
      info "Added ~/.local/bin to PATH in ~/.bashrc (run: source ~/.bashrc)"
    fi
    ;;
  zsh)
    if ! grep -q 'HOME/.local/bin' "$USER_HOME/.zshrc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.zshrc"
      info "Added ~/.local/bin to PATH in ~/.zshrc (run: source ~/.zshrc)"
    fi
    ;;
  fish)
    if have fish; then
      fish -c 'set -U fish_user_paths $HOME/.local/bin $fish_user_paths' || true
      info "Added ~/.local/bin to PATH (fish universal var)."
    fi
    ;;
  *) warn "Unknown shell ($shell_name). Make sure ~/.local/bin is on your PATH." ;;
esac

# ---- optional systemd user timer ----
if [[ $want_timer -eq 1 ]]; then
  info "Installing systemd --user service & timer to refresh cache…"
  mkdir -p "$SERVICE_DIR"
  cat > "$SRV" <<EOF
[Unit]
Description=Update Caelestia Stocks cache

[Service]
Type=oneshot
ExecStart=$LAUNCHER
EOF
  cat > "$TMR" <<'EOF'
[Unit]
Description=Run Caelestia Stocks every minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
AccuracySec=5s
Unit=caelestia-stocks.service

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now caelestia-stocks.timer
  ok "Timer enabled. It refreshes $CACHE every minute."
fi

# ---- test run ----
info "Testing command…"
if "$LAUNCHER" >/tmp/caelestia-stocks.out 2>/tmp/caelestia-stocks.err; then
  ok "Output: $(cat /tmp/caelestia-stocks.out)"
else
  warn "Command returned non-zero. Stderr:"
  sed -n '1,5p' /tmp/caelestia-stocks.err || true
fi

cat <<EOF

Use it anywhere (panel, runner, keybind, QML):
  caelestia-stocks        # live fetch
  caelestia-stocks --cached   # use last cached line (fast)

Edit your tickers:
  $TICKERS

If you enabled --timer, the latest line is cached at:
  $CACHE

Example Hyprland keybind (append to ~/.config/caelestia/hypr-user.conf):
  bind = \$mainMod, S, exec, notify-send "\$(caelestia-stocks --cached)"

Reload Hyprland afterwards.
EOF