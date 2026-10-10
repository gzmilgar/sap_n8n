#!/usr/bin/env zsh
# Start the whole demo on macOS: n8n and CAP.
#
#   ./start-demo.sh           two Terminal windows (what you want on stage)
#   ./start-demo.sh --tunnel  + public URL via cloudflared (Telegram onayı için ŞART)
#   ./start-demo.sh --bg      background + log files (quieter, for rehearsal)
#   ./start-demo.sh --cap     CAP only
#   ./start-demo.sh --n8n     n8n only
set -u
source "${0:A:h}/lib-demo.sh"

MODE="windows"; WANT_CAP=1; WANT_N8N=1; WANT_TUNNEL=0
for arg in "$@"; do
  case "$arg" in
    --tunnel) WANT_TUNNEL=1 ;;
    --bg)  MODE="bg" ;;
    --cap) WANT_N8N=0 ;;
    --n8n) WANT_CAP=0 ;;
    -h|--help) show_usage "$0"; exit 0 ;;
  esac
done

LOG_DIR="$REPO_ROOT/.demo-logs"
mkdir -p "$LOG_DIR"

head1 "SAP CAP + n8n demo (macOS)"

# --- 1) toolchain ------------------------------------------------------------
if ! ensure_node_on_path; then
  bad "node bulunamadı. nvm kullanıyorsan yeni bir terminal aç ve tekrar dene."
  exit 1
fi
NODE_BIN="$(node_bin_dir)"
info "node $(node --version)   ($NODE_BIN)"

for tool in cds n8n; do
  if ! command -v $tool >/dev/null 2>&1; then
    bad "$tool bulunamadı."
    [[ $tool == cds ]] && info "kur:  npm install -g @sap/cds-dk"
    [[ $tool == n8n ]] && info "kur:  npm install -g n8n"
    exit 1
  fi
done
info "cds $(cds --version 2>/dev/null | sed -n 's/.*@sap\/cds-dk (global) *\([0-9.]*\).*/\1/p' | head -1)   n8n $(n8n --version 2>/dev/null | tail -1)"

# --- 2) CAP project ----------------------------------------------------------
if [[ ! -f "$CAP_DIR/package.json" ]]; then
  bad "CAP projesi yok: $CAP_DIR"; exit 1
fi
if [[ ! -f "$CAP_DIR/.env" ]]; then
  cp "$CAP_DIR/.env.example" "$CAP_DIR/.env"
  warn ".env yoktu, .env.example'dan kopyalandı"
fi
if [[ ! -d "$CAP_DIR/node_modules" ]]; then
  warn "CAP bağımlılıkları kuruluyor (bir kerelik)…"
  ( cd "$CAP_DIR" && npm install --no-audit --no-fund >/dev/null 2>&1 ) \
    && ok "npm install bitti" || { bad "npm install başarısız"; exit 1; }
fi

# Spawned Terminal windows read .zshrc, but prepending the resolved bin dir
# makes this work even when nvm is not wired into the login shell.
run_in_terminal() {
  local title="$1" dir="$2" cmd="$3"
  osascript >/dev/null 2>&1 <<OSA
tell application "Terminal"
  do script "export PATH=\"$NODE_BIN:\$PATH\"; cd '$dir'; echo '--- $title ---'; $cmd"
  activate
end tell
OSA
}

run_in_bg() {
  local name="$1" dir="$2" cmd="$3"
  ( cd "$dir" && PATH="$NODE_BIN:$PATH" nohup sh -c "$cmd" > "$LOG_DIR/$name.log" 2>&1 & )
}

# --- 3) tunnel (only needed for the Telegram approval) -----------------------
PUBLIC_URL=""
if (( WANT_TUNNEL )); then
  if ! command -v cloudflared >/dev/null 2>&1; then
    bad "cloudflared yok  ->  brew install cloudflared"
    info "Tünelsiz devam edersen Telegram onayı çalışmaz; form moduna (04) geç."
    exit 1
  fi
  rm -f "$TUNNEL_URL_FILE"
  pkill -f "cloudflared tunnel" 2>/dev/null
  info "Tünel açılıyor…"
  ( cloudflared tunnel --url "$N8N_URL" > "$LOG_DIR/tunnel.log" 2>&1 & )
  for i in {1..30}; do
    PUBLIC_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/tunnel.log" 2>/dev/null | head -1)
    [[ -n "$PUBLIC_URL" ]] && break
    sleep 2
  done
  if [[ -z "$PUBLIC_URL" ]]; then
    bad "Tünel açılamadı - log: $LOG_DIR/tunnel.log"
    info "İnternet yoksa form moduna geç (04). Ayrıntı: README.md, 'Onay modları' bölümü"
    exit 1
  fi
  print -r -- "$PUBLIC_URL" > "$TUNNEL_URL_FILE"
  ok "Tünel hazır  $PUBLIC_URL"
fi

# --- 4) n8n ------------------------------------------------------------------
if (( WANT_N8N )); then
  if n8n_up; then
    ok "n8n zaten çalışıyor  $N8N_URL"
    (( WANT_TUNNEL )) && warn "n8n zaten açıktı - tüneli tanıması için: ./scripts/stop-demo.sh --n8n && ./scripts/start-demo.sh --tunnel"
  else
    info "n8n başlatılıyor…"
    # WEBHOOK_URL is what n8n puts into the Telegram approval buttons.
    # Tünel varsa public adres; yoksa açıkça localhost. Kabuktan miras kalan WEBHOOK_URL / N8N_WEBHOOK_URL
    # değerleri form ve buton linklerini bozabildiği için her iki durumda da açıkça veriyoruz.
    local_n8n_cmd="unset N8N_WEBHOOK_URL; WEBHOOK_URL='${PUBLIC_URL:-$N8N_URL/}' n8n"
    if [[ $MODE == windows ]]; then run_in_terminal "n8n :5678" "$REPO_ROOT" "$local_n8n_cmd"
    else run_in_bg "n8n" "$REPO_ROOT" "$local_n8n_cmd"; fi
    # n8n's first boot runs DB migrations, so give it a generous window.
    for i in {1..60}; do n8n_up && break; sleep 2; done
    n8n_up && ok "n8n hazır  $N8N_URL" || warn "n8n 120 sn'de yanıt vermedi - log: $LOG_DIR/n8n.log"
  fi
fi

# --- 5) CAP ------------------------------------------------------------------
if (( WANT_CAP )); then
  if cap_up; then
    ok "CAP zaten çalışıyor  $CAP_URL"
  else
    info "CAP başlatılıyor…"
    # .env'i zorla yükle: kabukta export edilmiş eski bir N8N_WEBHOOK_URL varsa cds onu .env ile ezmez,
    # CAP de yanlış workflow'a (örn. form modundayken 01'e) webhook atar. set -a ile dosya her zaman kazanır.
    CAP_CMD='set -a; . ./.env; set +a; cds watch'
    if [[ $MODE == windows ]]; then run_in_terminal "CAP :4004" "$CAP_DIR" "$CAP_CMD"
    else run_in_bg "cap" "$CAP_DIR" "$CAP_CMD"; fi
    for i in {1..30}; do cap_up && break; sleep 1; done
    cap_up && ok "CAP hazır  $CAP_URL" || warn "CAP yanıt vermedi - log: $LOG_DIR/cap.log"
  fi
fi

# --- 6) where to go next -----------------------------------------------------
head1 "Adresler"
print -r -- "  Fiori listesi : $CAP_URL/\$fiori-preview/OrderService/Orders#preview-app"
print -r -- "  OData         : $ODATA/Orders"
print -r -- "  n8n editörü   : $N8N_URL"
if [[ -n "$PUBLIC_URL" ]]; then
  print -r -- "  public (tünel): $PUBLIC_URL   <- Telegram butonları buradan geçer"
else
  print -r -- "  ${C_DIM}tünel yok -> Telegram onayı çalışmaz; form modu (04) kullan${C_RESET}"
fi
head1 "Sonraki adım"
print -r -- "  ./scripts/check-demo.sh              # sahne öncesi kontrol"
print -r -- "  ./scripts/create-order.sh -a 500     # otomatik onay"
print -r -- "  ./scripts/create-order.sh -a 15000   # onay iste"
print -r -- ""
