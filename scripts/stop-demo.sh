#!/usr/bin/env zsh
# Stop CAP and/or n8n started by start-demo.sh.
#
#   ./stop-demo.sh          ikisini de durdur
#   ./stop-demo.sh --n8n    sadece n8n  (dayanıklılık demosu için)
#   ./stop-demo.sh --cap    sadece CAP
set -u
source "${0:A:h}/lib-demo.sh"

WANT_CAP=1; WANT_N8N=1
for arg in "$@"; do
  case "$arg" in
    --n8n) WANT_CAP=0 ;;
    --cap) WANT_N8N=0 ;;
    -h|--help) show_usage "$0"; exit 0 ;;
  esac
done

head1 "Durduruluyor"

kill_matching() {
  local label="$1" pattern="$2" port="$3"
  local pids=$(pgrep -f "$pattern" 2>/dev/null | tr '\n' ' ')
  if [[ -n "${pids// /}" ]]; then
    print -r -- "$pids" | tr ' ' '\n' | grep -E '^[0-9]+$' | xargs kill 2>/dev/null
    ok "$label durduruldu"
  else
    info "$label zaten kapalı"
  fi
  sleep 2
  # Anything still holding the port gets a harder nudge.
  local held=$(lsof -ti:$port 2>/dev/null)
  [[ -n "$held" ]] && { print -r -- "$held" | xargs kill -9 2>/dev/null; warn "port $port zorla boşaltıldı"; }
  sleep 1
  lsof -ti:$port >/dev/null 2>&1 && bad "port $port hâlâ dolu" || ok "port $port boş"
}

(( WANT_CAP )) && kill_matching "CAP" "cds watch|cds-serve" 4004
(( WANT_N8N )) && kill_matching "n8n" "bin/n8n|n8n start|task-runner" 5678

# The tunnel only serves n8n, so it goes down with it.
if (( WANT_N8N )); then
  if pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
    pkill -f "cloudflared tunnel" 2>/dev/null && ok "tünel kapatıldı"
  fi
  rm -f "$TUNNEL_URL_FILE"
fi

if (( WANT_N8N )) && (( ! WANT_CAP )); then
  print -r -- ""
  info "n8n kapalı. Şimdi sipariş açarsan CAP yine 201 döner, sadece uyarı loglar:"
  info "  ./scripts/create-order.sh -a 700"
fi
