#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Caelestia Stocks – One-shot installer
# - Creates a python venv under ~/.local/share/caelestia-stocks/venv
# - Installs yfinance (and deps) in the venv
# - Writes a tiny Python fetcher and a wrapper binary: ~/.local/bin/caelestia-stocks
# - Sets up a cache + optional systemd user timer (off by default; enable with --timer)
# - Adds a default tickers file: ~/.config/caelestia/stocks.txt
# ===============================

### UX helpers
cinfo()  { printf "\033[1;36m[i]\033[0m %s\n" "$*"; }
cok()    { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
cwarn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
cfail()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }
die()    { cfail "$*"; exit 1; }

### Resolve target user and HOME even when run with sudo
TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -z "${TARGET_HOME}" ]] && TARGET_HOME="$HOME"

### Paths
BASE_DIR="$TARGET_HOME/.local/share/caelestia-stocks"
VENV_DIR="$BASE_DIR/venv"
BIN_DIR="$TARGET_HOME/.local/bin"
CONF_DIR="$TARGET_HOME/.config/caelestia"
TICKERS_FILE="$CONF_DIR/stocks.txt"
CACHE_FILE="$BASE_DIR/cache.json"
WRAPPER_BIN="$BIN_DIR/caelestia-stocks"
FETCH_PY="$BASE_DIR/stocks_fetch.py"
PRINT_PY="$BASE_DIR/stocks_print.py"
SVC_DIR="$TARGET_HOME/.config/systemd/user"
SVC_FILE="$SVC_DIR/caelestia-stocks.service"
TMR_FILE="$SVC_DIR/caelestia-stocks.timer"

# Whether to install + enable systemd timer
USE_TIMER=0
if [[ "${1-}" == "--timer" ]]; then USE_TIMER=1; fi

### Run-as-user helper (even if script was launched with sudo)
if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  RUN_AS_USER=(sudo -u "$TARGET_USER" -H)
else
  RUN_AS_USER=()
fi

cinfo "Installing Caelestia Stocks for user: $TARGET_USER"
cinfo "Home: $TARGET_HOME"

# 1) Ensure base dirs
mkdir -p "$BASE_DIR" "$BIN_DIR" "$CONF_DIR" "$SVC_DIR"

# 2) Ensure python + venv tooling
cinfo "Ensuring Python and venv tools…"
if command -v python >/dev/null 2>&1; then
  cok "python is present"
else
  if [[ "$EUID" -ne 0 ]]; then
    cwarn "python is missing. Install with: sudo pacman -S python"
  else
    pacman -Sy --noconfirm --needed python || die "Failed to install python"
  fi
fi

# Arch packages: python-pip is useful; python-virtualenv provides 'virtualenv' but we use 'python -m venv'
if [[ "$EUID" -eq 0 ]]; then
  pacman -Sy --noconfirm --needed python-pip >/dev/null || true
fi

# 3) Create venv (idempotent)
if [[ ! -d "$VENV_DIR" ]]; then
  cinfo "Creating venv at: $VENV_DIR"
  mkdir -p "$BASE_DIR"
  "${RUN_AS_USER[@]}" python -m venv "$VENV_DIR" || die "Failed to create venv"
else
  cok "Venv already exists"
fi

# 4) Upgrade pip & install deps in venv
cinfo "Installing Python deps in venv (yfinance, requests)…"
"${RUN_AS_USER[@]}" bash -lc "source '$VENV_DIR/bin/activate' \
  && python -m pip install --upgrade pip >/dev/null \
  && python -m pip install --disable-pip-version-check -q yfinance requests" \
  || die "pip install failed"

cok "Python deps installed"

# 5) Default tickers file (idempotent)
if [[ ! -f "$TICKERS_FILE" ]]; then
  cat >"$TICKERS_FILE" <<'EOF'
# One ticker per line. NSE use .NS suffix.
# Examples:
INFY.NS
TCS.NS
HDFCBANK.NS
^NSEI
AAPL
MSFT
EOF
  chown "$TARGET_USER":"$TARGET_USER" "$TICKERS_FILE"
  cok "Created $TICKERS_FILE (edit to your liking)"
else
  cok "Tickers file already exists ($TICKERS_FILE)"
fi

# 6) Write Python fetcher (creates/refreshes cache.json)
cat >"$FETCH_PY" <<'PYEOF'
import os, sys, json, time
from datetime import datetime
TICKERS_ENV = os.environ.get("CAE_STOCK_TICKERS", "").strip()
TICKERS_FILE = os.environ.get("CAE_STOCK_TICKERS_FILE", os.path.expanduser("~/.config/caelestia/stocks.txt"))
CACHE_FILE   = os.environ.get("CAE_STOCK_CACHE",        os.path.expanduser("~/.local/share/caelestia-stocks/cache.json"))

def load_tickers():
    if TICKERS_ENV:
        return [t.strip() for t in TICKERS_ENV.split(",") if t.strip()]
    try:
        with open(TICKERS_FILE, "r") as f:
            lines = []
            for line in f:
                s=line.strip()
                if not s or s.startswith("#"): continue
                lines.append(s)
            return lines
    except Exception:
        return []

def fetch(tickers):
    import yfinance as yf
    out=[]
    if not tickers:
        return out
    data = yf.download(tickers=" ".join(tickers), period="1d", interval="1m", progress=False, threads=True)
    # When multiple tickers, columns are MultiIndex; simplify:
    now = datetime.now().isoformat(timespec="seconds")
    for t in tickers:
        try:
            # preferred: use fast info
            info = yf.Ticker(t).fast_info
            price = float(info.get("last_price") or info.get("last_close") or 0.0)
            pc    = float(info.get("previous_close") or 0.0)
        except Exception:
            # fallback from download frame
            try:
                if isinstance(data.columns, tuple) or hasattr(data.columns, "levels"):
                    close_series = data["Close"][t].dropna()
                else:
                    close_series = data["Close"].dropna()
                price = float(close_series.iloc[-1])
                pc    = float(close_series.iloc[0])
            except Exception:
                continue
        if price == 0 or pc == 0:
            chg_pct = 0.0
        else:
            chg_pct = (price - pc) / pc * 100.0
        out.append({
            "ticker": t,
            "price": round(price, 2),
            "change_pct": round(chg_pct, 2),
            "ts": now
        })
    return out

def main():
    tickers = load_tickers()
    try:
        data = fetch(tickers)
    except Exception as e:
        data = {"error": str(e), "tickers": tickers, "ts": datetime.now().isoformat(timespec="seconds")}
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump({"data": data, "ts": int(time.time())}, f)
    print(CACHE_FILE)

if __name__ == "__main__":
    main()
PYEOF
chown "$TARGET_USER":"$TARGET_USER" "$FETCH_PY"

# 7) Write quick printer (reads cache and prints compact line)
cat >"$PRINT_PY" <<'PYEOF'
import os, json
CACHE_FILE = os.environ.get("CAE_STOCK_CACHE", os.path.expanduser("~/.local/share/caelestia-stocks/cache.json"))
if not os.path.exists(CACHE_FILE):
    print("stocks: no cache")
    raise SystemExit(0)
try:
    with open(CACHE_FILE, "r") as f:
        payload = json.load(f)
    rows = payload.get("data", [])
except Exception:
    print("stocks: bad cache")
    raise SystemExit(0)

def fmt(row):
    t = row["ticker"]
    p = f'{row["price"]:.2f}'
    ch = float(row["change_pct"])
    arrow = "▲" if ch >= 0 else "▼"
    return f"{t} {p} {arrow}{abs(ch):.2f}%"

print("  |  ".join(fmt(r) for r in rows[:6]))
PYEOF
chown "$TARGET_USER":"$TARGET_USER" "$PRINT_PY"

# 8) Wrapper binary: ~/.local/bin/caelestia-stocks
cat >"$WRAPPER_BIN" <<'SHEOF'
#!/usr/bin/env bash
set -euo pipefail
VENV="$HOME/.local/share/caelestia-stocks/venv"
BASE="$HOME/.local/share/caelestia-stocks"
FETCH="$BASE/stocks_fetch.py"
PRINT="$BASE/stocks_print.py"

# Refresh cache if older than 45s (lightweight)
needs_refresh() {
  [[ ! -f "$BASE/cache.json" ]] && return 0
  now=$(date +%s)
  mtime=$(stat -c %Y "$BASE/cache.json" 2>/dev/null || echo 0)
  (( now - mtime > 45 ))
}

if needs_refresh; then
  "$VENV/bin/python" "$FETCH" >/dev/null 2>&1 || true
fi
exec "$VENV/bin/python" "$PRINT"
SHEOF
chmod +x "$WRAPPER_BIN"
chown "$TARGET_USER":"$TARGET_USER" "$WRAPPER_BIN"
cok "Installed command: $WRAPPER_BIN"

# 9) Optional systemd user service/timer (off by default)
if (( USE_TIMER )); then
  cinfo "Writing systemd user service + timer (refresh every 30s)…"
  cat >"$SVC_FILE" <<SVC
[Unit]
Description=Caelestia Stocks Cache Updater

[Service]
Type=oneshot
ExecStart=$VENV_DIR/bin/python $FETCH_PY
TimeoutSec=20
SVC
  cat >"$TMR_FILE" <<TMR
[Unit]
Description=Run Caelestia Stocks updater every 30 seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
Unit=$(basename "$SVC_FILE")

[Install]
WantedBy=default.target
TMR
  chown "$TARGET_USER":"$TARGET_USER" "$SVC_FILE" "$TMR_FILE"
  "${RUN_AS_USER[@]}" systemctl --user daemon-reload
  "${RUN_AS_USER[@]}" systemctl --user enable --now "$(basename "$TMR_FILE")"
  cok "Timer enabled (systemctl --user status $(basename "$TMR_FILE"))"
else
  cinfo "Timer not enabled. Re-run with '--timer' to install background refresh."
fi

# 10) Final hints for Caelestia/Hyprland integration
cat <<'NOTE'

────────────────────────────────────────────────────────────────
✅ Done.

Use this command anywhere (panel, keybind, runner, qml):
    caelestia-stocks

It prints a compact line like:
    INFY.NS 1523.45 ▲0.80%  |  TCS.NS 4021.10 ▲0.15%  |  …

Edit your tickers here:
    ~/.config/caelestia/stocks.txt
(One per line; NSE uses .NS suffix; supports ^NSEI, AAPL, etc.)

QML/panel integration idea (poll the command):
    // In your QML, run caeslestia-stocks and display stdout
    // Example snippets were printed in earlier instructions.

Hyprland keybind example (append to ~/.config/caelestia/hypr-user.conf):
    bind = $mainMod, S, exec, notify-send "$(caelestia-stocks)"

(Then reload Hyprland.)

NOTE
cok "Caelestia Stocks setup complete."