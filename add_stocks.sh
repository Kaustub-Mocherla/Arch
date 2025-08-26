#!/usr/bin/env bash
set -Eeuo pipefail

# ===========================
# Caelestia Stocks Integration
# ===========================
# - Installs Python venv + yfinance
# - Creates fetcher -> ~/.cache/caelestia/stocks/line.txt
# - Creates systemd --user (service+timer) to refresh each minute
# - Creates a Quickshell overlay config to display the line (no Caelestia edits)
# - Autostarts overlay via Hyprland exec-once
#
# Usage:
#   ./add_stocks_auto.sh "INFY.NS,TCS.NS,RELIANCE.NS"
#   (Symbols are optional; defaults are used if omitted)
#
# Re-run any time; it is idempotent.

SYMBOLS_INPUT="${1:-"INFY.NS,TCS.NS,RELIANCE.NS"}"

# --- find real user (if run with sudo) ---
if [[ $EUID -eq 0 ]]; then
  REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
  [[ -n "$REAL_USER" ]] || { echo "[x] Cannot figure out non-root user"; exit 1; }
  USER_HOME="$(eval echo ~"$REAL_USER")"
  RUN_AS_USER=(su - "$REAL_USER" -c)
else
  REAL_USER="$USER"
  USER_HOME="$HOME"
  RUN_AS_USER=()
fi

# --- pretty helpers ---
g='\033[1;32m'; y='\033[1;33m'; r='\033[1;31m'; c='\033[1;36m'; n='\033[0m'
msg(){ echo -e "${c}[i]${n} $*"; }
ok(){  echo -e "${g}[✓]${n} $*"; }
warn(){ echo -e "${y}[!]${n} $*"; }
die(){ echo -e "${r}[x]${n} $*"; exit 1; }

# --- paths ---
ROOT_DIR="$USER_HOME/.local/share/caelestia-stocks"
VENV_DIR="$ROOT_DIR/venv"
CACHE_DIR="$USER_HOME/.cache/caelestia/stocks"
OUT_TXT="$CACHE_DIR/line.txt"
UNIT_DIR="$USER_HOME/.config/systemd/user"

QS_DIR="$USER_HOME/.config/quickshell"
OVERLAY_NAME="caelestia-stocks-overlay"
OVERLAY_DIR="$QS_DIR/$OVERLAY_NAME"
OVERLAY_ENTRY="$OVERLAY_DIR/main.qml"

HYPR_DIR="$USER_HOME/.config/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

mkdir -p "$ROOT_DIR" "$CACHE_DIR" "$UNIT_DIR" "$OVERLAY_DIR" "$HYPR_DIR"

# --- ensure python + venv tools ---
msg "Ensuring Python and venv tools…"
if [[ $EUID -eq 0 ]]; then
  pacman -Sy --noconfirm --needed python python-venv python-pip >/dev/null || true
else
  warn "Not root; if python/venv is missing, install: sudo pacman -S python python-venv python-pip"
fi

# --- create venv + yfinance ---
if [[ ! -d "$VENV_DIR" ]]; then
  "${RUN_AS_USER[@]}" "python -m venv '$VENV_DIR'" || die "Failed to create venv"
fi

msg "Installing yfinance into venv…"
"${RUN_AS_USER[@]}" "'$VENV_DIR/bin/python' -m pip install --upgrade pip >/dev/null 2>&1 || true"
"${RUN_AS_USER[@]}" "'$VENV_DIR/bin/pip' install --upgrade yfinance >/dev/null 2>&1" || die "pip install yfinance failed"

# --- write fetcher script ---
FETCHER="$ROOT_DIR/stocks_ticker.py"
cat > "$FETCHER" <<'PY'
#!/usr/bin/env python3
import os
from pathlib import Path
import yfinance as yf

symbols = os.getenv("SYMBOLS", "INFY.NS,TCS.NS,RELIANCE.NS")
symbols = [s.strip() for s in symbols.split(",") if s.strip()]
out_path = Path.home() / ".cache/caelestia/stocks/line.txt"
out_path.parent.mkdir(parents=True, exist_ok=True)

def fetch(sym):
    t = yf.Ticker(sym)
    price = None; prev = None
    # Try fast_info first
    try:
        fi = t.fast_info
        price = float(fi["last_price"])
        prev = float(fi.get("previous_close") or fi.get("regular_market_previous_close") or 0.0)
    except Exception:
        pass
    # Fallback: history
    if price is None or not prev:
        try:
            h = t.history(period="2d", interval="1d")
            if not h.empty:
                price = float(h["Close"].iloc[-1])
                if len(h) > 1:
                    prev = float(h["Close"].iloc[-2])
        except Exception:
            pass
    if price is None:
        return f"{sym} ??.?? --"
    pct = (price - prev) / prev * 100 if prev else 0.0
    arrow = "▲" if pct >= 0 else "▼"
    return f"{sym} {price:.2f} {arrow}{abs(pct):.2f}%"

line = " | ".join(fetch(s) for s in symbols)
with open(out_path, "w") as f:
    f.write(line + "\n")
print(line)
PY
chmod +x "$FETCHER"
chown -R "$REAL_USER":"$REAL_USER" "$ROOT_DIR" "$CACHE_DIR"

# --- wrapper to call fetcher with env ---
RUNNER="$ROOT_DIR/run_once.sh"
cat > "$RUNNER" <<SH
#!/usr/bin/env bash
set -Eeuo pipefail
export SYMBOLS="${SYMBOLS_INPUT}"
exec "$VENV_DIR/bin/python" "$FETCHER"
SH
chmod +x "$RUNNER"
chown "$REAL_USER":"$REAL_USER" "$RUNNER"

# --- systemd user units: service + timer ---
cat > "$UNIT_DIR/caelestia-stocks.service" <<SERVICE
[Unit]
Description=Update Caelestia stocks line

[Service]
Type=oneshot
Environment=SYMBOLS=${SYMBOLS_INPUT}
ExecStart=${RUNNER}
WorkingDirectory=${ROOT_DIR}
SERVICE

cat > "$UNIT_DIR/caelestia-stocks.timer" <<TIMER
[Unit]
Description=Update Caelestia stocks line every minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
AccuracySec=10s
Unit=caelestia-stocks.service

[Install]
WantedBy=default.target
TIMER

chown -R "$REAL_USER":"$REAL_USER" "$UNIT_DIR"

# --- first fetch + enable timer (user session) ---
msg "Running first fetch…"
"${RUN_AS_USER[@]}" "SYSTEMD_EXIT_STATUS=0 ${RUNNER} >/dev/null 2>&1 || true"
ok "Output at: $OUT_TXT"

msg "Enabling systemd --user timer…"
"${RUN_AS_USER[@]}" "systemctl --user daemon-reload"
"${RUN_AS_USER[@]}" "systemctl --user enable --now caelestia-stocks.timer"

# --- Quickshell overlay (non-invasive) ---
# Tiny translucent bar at top-right reading the file every 3s
cat > "$OVERLAY_ENTRY" <<'QML'
import QtQuick 2.15
import QtQuick.Window 2.15

Window {
  id: root
  width: textItem.implicitWidth + 24
  height: textItem.implicitHeight + 12
  flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
  color: "#1A000000" // translucent
  visible: true

  // Top-right corner
  x: Screen.virtualX + Screen.width - width - 16
  y: Screen.virtualY + 16

  Text {
    id: textItem
    anchors.centerIn: parent
    text: ""
    color: "#e6e6e6"
    font.family: "CaskaydiaCove Nerd Font"
    font.pixelSize: 14
  }

  Timer {
    interval: 3000; repeat: true; running: true
    onTriggered: {
      var f = Qt.openUrlExternally ? null : null; // NOOP
      try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + Qt.resolvedUrl("~/.cache/caelestia/stocks/line.txt"));
        xhr.onreadystatechange = function() {
          if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 0) {
            textItem.text = xhr.responseText.trim();
          }
        }
        xhr.send();
      } catch (e) { /* ignore */ }
    }
    Component.onCompleted: triggered()
  }
}
QML

chown -R "$REAL_USER":"$REAL_USER" "$OVERLAY_DIR"

# --- Autostart overlay via Hyprland exec-once (idempotent) ---
mkdir -p "$HYPR_DIR"
touch "$HYPR_CONF"
if ! grep -q "qs -c $OVERLAY_NAME" "$HYPR_CONF"; then
  echo -e "\n# Stocks overlay" >> "$HYPR_CONF"
  echo "exec-once = qs -c $OVERLAY_NAME" >> "$HYPR_CONF"
  ok "Added overlay autostart to Hyprland."
else
  msg "Overlay autostart already present in Hyprland."
fi

# --- Done ---
ok "Stocks integration installed."
echo -e "${c}Watchlist:${n} $SYMBOLS_INPUT"
echo -e "${c}Output file:${n} $OUT_TXT"
echo -e "${c}Overlay config:${n} $OVERLAY_ENTRY"
echo -e "${c}Change symbols:${n} edit ${UNIT_DIR}/caelestia-stocks.service (Environment=SYMBOLS=...)"
echo -e "Then run: ${g}systemctl --user restart caelestia-stocks.service${n} (as $REAL_USER)"