#!/usr/bin/env zsh
# Poll one order until its status leaves PENDING (or the timeout hits).
#   ./watch-order.sh <order-id> [saniye]
set -u
source "${0:A:h}/lib-demo.sh"

for arg in "$@"; do
  case "$arg" in
    -h|--help) show_usage "$0"; exit 0 ;;
  esac
done

ID="${1:-}"
LIMIT="${2:-60}"
if [[ -z "$ID" ]]; then
  bad "Kullanım: ./watch-order.sh <order-id> [saniye]"
  exit 2
fi

if ! cap_up; then
  bad "CAP ayakta değil ($ODATA)"
  info "Önce çalıştır:  ./scripts/start-demo.sh"
  exit 2
fi

# Fail fast on a bad id instead of polling a non-existent order for a minute.
CODE=$(http_code "$ODATA/Orders($ID)")
if [[ "$CODE" == "404" ]]; then
  bad "Böyle bir sipariş yok: $ID"
  exit 2
elif [[ "$CODE" != "200" ]]; then
  bad "Sipariş okunamadı (HTTP $CODE)"
  exit 2
fi

head1 "Sipariş izleniyor: $ID"
START=$SECONDS
LAST=""
while (( SECONDS - START < LIMIT )); do
  LINE=$(curl -s --max-time 4 "$ODATA/Orders($ID)" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("?|?|?"); raise SystemExit
print("%s|%s|%s" % (d.get("status"), d.get("approvedBy") or "-", d.get("note") or "-"))
' 2>/dev/null)
  STATUS="${LINE%%|*}"
  REST="${LINE#*|}"; APPROVER="${REST%%|*}"; NOTE="${REST#*|}"

  if [[ "$LINE" != "$LAST" ]]; then
    case "$STATUS" in
      APPROVED) ok  "APPROVED  · onaylayan: $APPROVER  ($(( SECONDS - START ))s)"; exit 0 ;;
      REJECTED) bad "REJECTED  · not: $NOTE  ($(( SECONDS - START ))s)"; exit 0 ;;
      PENDING)  info "PENDING… onay bekleniyor" ;;
      *)        warn "durum okunamadı (CAP yanıt vermiyor olabilir)" ;;
    esac
    LAST="$LINE"
  fi
  sleep 1
done

warn "$LIMIT saniyede sonuçlanmadı - hâlâ PENDING"
info "Onay bekleniyor olabilir: Telegram'a bak, ya da n8n'de $N8N_URL/home/executions"
exit 1
