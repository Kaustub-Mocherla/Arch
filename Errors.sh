bash -euo pipefail <<'EOF'
echo "=== Caelestia + Stocks (deps, fonts, modules, launcher, wallpaper, stocks) ==="

USER_HOME="$HOME"
CFG_DIR="$USER_HOME/.config/quickshell/caelestia"
MOD_DIR="$CFG_DIR/modules"
CACHE_DIR="$USER_HOME/.cache/caelestia-src"
LAUNCHER="$HOME/.local/bin/caelestia-shell"
BIN_STOCKS="$HOME/.local/bin/ce-stocks"
STOCKS_DATA_DIR="$CFG_DIR/services/data"
STOCKS_CONF_DIR="$CFG_DIR/config"
STOCKS_CONF_FILE="$STOCKS_CONF_DIR/stocks.txt"

# ---------- 0) Helpers ----------
rsync_has_delete() { rsync -a --delete "$1" "$2"; }

# ---------- 1) Packages ----------
echo "[1/8] Installing runtime tools (pacman)…"
sudo pacman -Sy --needed --noconfirm \
  swww playerctl pamixer brightnessctl jq \
  wl-clipboard grim slurp swappy \
  noto-fonts ttf-liberation ttf-cascadia-code-nerd \
  unzip curl

# ---------- 2) Fonts: Material Symbols Rounded ----------
echo "[2/8] Installing Material Symbols Rounded (variable TTF)…"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
mkdir -p "$FONT_DIR"
TMP="$(mktemp -d)"
TTF_NAME="MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
TTF_URL="https://github.com/google/material-design-icons/blob/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf?raw=1"
curl -fL --retry 3 --retry-delay 2 -o "$TMP/$TTF_NAME" "$TTF_URL" || true
if [ -s "$TMP/$TTF_NAME" ] && [ "$(stat -c%s "$TMP/$TTF_NAME")" -gt 1000000 ]; then
  install -m 0644 "$TMP/$TTF_NAME" "$FONT_DIR/$TTF_NAME"
  fc-cache -f "$FONT_DIR" >/dev/null || true
  echo "✓ Material Symbols installed."
else
  echo "!! Could not fetch Material Symbols (continuing)."
fi
rm -rf "$TMP"

# ---------- 3) Pull Caelestia sources ----------
echo "[3/8] Syncing Caelestia sources…"
mkdir -p "$CACHE_DIR"
if [ -d "$CACHE_DIR/caelestia/.git" ]; then
  git -C "$CACHE_DIR/caelestia" fetch --all -p
  git -C "$CACHE_DIR/caelestia" reset --hard origin/main || true
else
  git clone https://github.com/caelestia-dots/caelestia "$CACHE_DIR/caelestia"
fi
if [ -d "$CACHE_DIR/shell/.git" ]; then
  git -C "$CACHE_DIR/shell" fetch --all -p
  git -C "$CACHE_DIR/shell" reset --hard origin/main || true
else
  git clone https://github.com/caelestia-dots/shell "$CACHE_DIR/shell"
fi

# ---------- 4) Install shell + modules ----------
echo "[4/8] Installing shell files to $CFG_DIR …"
mkdir -p "$CFG_DIR"
install -m 0644 "$CACHE_DIR/shell/shell.qml" "$CFG_DIR/shell.qml"
rsync -a --delete "$CACHE_DIR/shell/modules/" "$CFG_DIR/modules/"

# Copy base building blocks from main repo
for d in components services config utils; do
  if [ -d "$CACHE_DIR/caelestia/$d" ]; then
    mkdir -p "$MOD_DIR/$d"
    rsync -a --delete "$CACHE_DIR/caelestia/$d/" "$MOD_DIR/$d/"
  else
    echo "!! Main repo missing '$d' (continuing)."
  fi
done

# ---------- 5) Launcher ----------
echo "[5/8] Writing launcher…"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<LAU
#!/usr/bin/env bash
set -euo pipefail
CE_DIR="\$HOME/.config/quickshell/caelestia"
export QML2_IMPORT_PATH="\$CE_DIR/modules\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
exec quickshell -c "\$CE_DIR"
LAU
chmod +x "$LAUNCHER"

# ---------- 6) Stocks: config + fetcher + systemd ----------
echo "[6/8] Setting up Stocks fetcher…"
mkdir -p "$STOCKS_DATA_DIR" "$STOCKS_CONF_DIR" "$HOME/.config/systemd/user" "$HOME/.local/bin"

# default tickers if file absent
if [ ! -s "$STOCKS_CONF_FILE" ]; then
  cat > "$STOCKS_CONF_FILE" <<CONF
AAPL
MSFT
TSLA
NVDA
BTC-USD
ETH-USD
CONF
fi

# fetcher script (Yahoo Finance public quote API)
cat > "$BIN_STOCKS" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
CFG_DIR="$HOME/.config/quickshell/caelestia"
TICKERS_FILE="$CFG_DIR/config/stocks.txt"
OUT="$CFG_DIR/services/data/stocks.json"
mkdir -p "$(dirname "$OUT")"
mapfile -t T < <(grep -E '^[A-Za-z0-9._-]+$' "$TICKERS_FILE" 2>/dev/null || true)
[ "${#T[@]}" -eq 0 ] && { echo '{"error":"no tickers"}' > "$OUT"; exit 0; }
SYMS=$(IFS=, ; echo "${T[*]}")
URL="https://query1.finance.yahoo.com/v7/finance/quote?symbols=${SYMS}"
JSON=$(curl -fsL --max-time 10 "$URL" || echo '{}')
# Normalize to tiny structure { ts, quotes: [ {symbol, price, change, changePct, currency, name} ] }
jq -c 'def pct(a;b): if a==null or b==null or b==0 then null else (a-b)/b*100 end;
  .quoteResponse.result
  | map({
      symbol: .symbol,
      name: (.shortName // .longName // .symbol),
      currency: (.currency // "USD"),
      price: (.regularMarketPrice // .postMarketPrice // .preMarketPrice // null),
      prevClose: (.regularMarketPreviousClose // null)
    }
    | . + {
      change: (if (.price!=null and .prevClose!=null) then (.price - .prevClose) else null end),
      changePct: (if (.price!=null and .prevClose!=null and .prevClose!=0) then ((.price - .prevClose) / .prevClose * 100) else null end)
    })
  | { ts: (now|floor), quotes: . }' <<<"$JSON" > "$OUT".tmp 2>/dev/null || { echo '{"error":"parse"}' > "$OUT"; exit 0; }
mv "$OUT".tmp "$OUT"
BASH
chmod +x "$BIN_STOCKS"

# systemd user service + timer
cat > "$HOME/.config/systemd/user/ce-stocks.service" <<UNIT
[Unit]
Description=Caelestia Stocks fetcher

[Service]
Type=oneshot
ExecStart=$BIN_STOCKS
UNIT

cat > "$HOME/.config/systemd/user/ce-stocks.timer" <<UNIT
[Unit]
Description=Refresh Caelestia Stocks every 5 minutes

[Timer]
OnBootSec=10s
OnUnitActiveSec=5min
Unit=ce-stocks.service

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now ce-stocks.timer
# do an immediate fetch so JSON exists
"$BIN_STOCKS" || true

# ---------- 7) QML helper (optional import) ----------
echo "[7/8] Installing QML helper for stocks…"
STOCKS_QML_DIR="$MOD_DIR/services/stocks"
mkdir -p "$STOCKS_QML_DIR"
cat > "$STOCKS_QML_DIR/Data.qml" <<'QML'
import QtQuick 2.15
QtObject {
  id: root
  // path where ce-stocks writes JSON
  property url jsonPath: Qt.resolvedUrl("../../services/data/stocks.json")
  property var data: ({ ts: 0, quotes: [] })

  function load() {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try { root.data = JSON.parse(xhr.responseText) } catch(e) { }
      }
    }
    xhr.open("GET", jsonPath)
    xhr.send()
  }

  Timer {
    interval: 15000; running: true; repeat: true
    onTriggered: root.load()
  }
  Component.onCompleted: load()
}
QML

# ---------- 8) Wallpaper bootstrap ----------
echo "[8/8] Ensuring swww is running; trying to set a wallpaper …"
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init || true
fi
CAND=""
for d in "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME"; do
  CAND="$(find "$d" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | head -n1 || true)"
  [ -n "$CAND" ] && break
done
if [ -n "${CAND:-}" ]; then
  swwW img "$CAND" --transition-type any 2>/dev/null || swww img "$CAND" --transition-type any || true
fi

echo
echo "✓ All set."
echo "Run inside Hyprland:  caelestia-shell"
echo
echo "Stocks:"
echo "  • Edit tickers in: $STOCKS_CONF_FILE  (one per line; e.g. AAPL, TSLA, BTC-USD)"
echo "  • Data JSON:       $STOCKS_DATA_DIR/stocks.json  (auto-refreshes every 5 min)"
echo "  • QML helper:      import \"services/stocks\" as Stocks; Stocks.Data { id: stocks }"
echo
EOF