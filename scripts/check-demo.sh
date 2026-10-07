#!/usr/bin/env zsh
# Pre-flight check. Run this right before you present.
# Exits non-zero if anything that would break the demo is wrong.
set -u
source "${0:A:h}/lib-demo.sh"

FULL=0
for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    -h|--help) show_usage "$0"; print -r -- "  --full  gerçek sipariş açıp tüm zinciri dener"; exit 0 ;;
  esac
done

FAILED=0
note() { FAILED=1; }

head1 "1 · Araçlar"
ensure_node_on_path
if command -v node >/dev/null 2>&1; then ok "node $(node --version)"; else bad "node yok"; note; fi
if command -v cds  >/dev/null 2>&1; then ok "cds  $(cds --version 2>/dev/null | sed -n 's/.*cds-dk (global) *\([0-9.]*\).*/\1/p' | head -1)"; else bad "cds yok  (npm i -g @sap/cds-dk)"; note; fi
if command -v n8n  >/dev/null 2>&1; then ok "n8n  $(n8n --version 2>/dev/null | tail -1)"; else bad "n8n yok  (npm i -g n8n)"; note; fi

head1 "2 · CAP servisi"
if cap_up; then
  COUNT=$(curl -s --max-time 4 "$ODATA/Orders/\$count" 2>/dev/null)
  ok "CAP ayakta  ($CAP_URL)"
  if [[ "$COUNT" == "3" ]]; then
    ok "3 başlangıç siparişi yüklü"
  else
    warn "sipariş sayısı: $COUNT  (prova siparişleri duruyor - temiz başlangıç için CAP'i yeniden başlat)"
  fi
  [[ "$(http_code "$CAP_URL/\$fiori-preview/OrderService/Orders")" == "200" ]] \
    && ok "Fiori preview yanıt veriyor" || { bad "Fiori preview açılmıyor"; note; }
else
  bad "CAP kapalı  ->  ./scripts/start-demo.sh"; note
fi

head1 "3 · n8n"
if n8n_up; then
  ok "n8n ayakta  ($N8N_URL)"
else
  bad "n8n kapalı  ->  ./scripts/start-demo.sh"; note
fi

head1 "4 · Webhook zinciri"
KEY=$(env_value N8N_WEBHOOK_KEY || true)
URL=$(env_value N8N_WEBHOOK_URL || true)
if [[ -z "${URL:-}" ]]; then
  bad "order-demo/.env içinde N8N_WEBHOOK_URL yok"; note
else
  info "hedef: $URL"
  if n8n_up; then
    CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 -X POST "$URL" \
      -H 'Content-Type: application/json' -H "X-API-Key: ${KEY:-}" \
      -d '{"ID":"00000000-0000-0000-0000-000000000000","customer":"preflight","product":"preflight","qty":1,"amount":1,"currency":"TRY"}')
    case "$CODE" in
      200) ok "webhook canlı ve anahtar doğru (HTTP 200)"
           info "not: bu test CAP'te olmayan bir ID gönderir, n8n tarafında 1 hatalı execution görürsün - normal" ;;
      403) bad "HTTP 403 - X-API-Key uyuşmuyor. n8n'deki 'CAP Webhook Key' credential Value = '$KEY' olmalı"; note ;;
      404) bad "HTTP 404 - workflow aktif değil. n8n'de workflow'u aç -> Activate"; note ;;
      *)   bad "webhook yanıtı: HTTP $CODE"; note ;;
    esac
  else
    warn "n8n kapalı olduğu için webhook test edilemedi"
  fi
fi

head1 "5 · Onay kanalı"
if [[ "${URL:-}" == *offline* ]]; then
  ok "FORM modu: onay n8n formundan alınacak"
  info "internet ve tünel gerekmez - en güvenli mod"
else
  info "TELEGRAM modu"
  PUB=$(tunnel_url)
  if [[ -n "$PUB" ]] && pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
    CODE=$(http_code "$PUB/healthz" 15)
    if [[ "$CODE" == "200" ]]; then
      ok "tünel ayakta: $PUB"
    else
      bad "tünel URL'i var ama yanıt vermiyor (HTTP $CODE)"; note
    fi
  else
    bad "tünel YOK - Telegram onay butonları çalışmaz"; note
    info "Telegram, localhost'a giden butonları reddeder."
    info "çözüm:  ./scripts/stop-demo.sh && ./scripts/start-demo.sh --tunnel"
    info "ya da form moduna geç (README.md, 'İki onay modu' bölümü)"
  fi
  info "onay butonuna bu Mac'teki tarayıcıdan bas (Telegram Web açık olsun)"
fi

if (( FULL )) && ! (( FAILED )); then
  head1 "6 · Gerçek tur (uçtan uca)"
  RESP=$(curl -s -X POST "$ODATA/Orders" -H 'Content-Type: application/json' \
    -d '{"customer":"Ege Teknik Sanayi Ltd.","product":"Conta Seti 100lük","qty":5,"amount":500.00}')
  NEW_ID=$(print -r -- "$RESP" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("ID",""))' 2>/dev/null)
  if [[ -z "$NEW_ID" ]]; then
    bad "sipariş oluşturulamadı"; note
  else
    info "500 TRY sipariş açıldı: $NEW_ID"
    RESULT=""
    for i in {1..15}; do
      sleep 1
      RESULT=$(curl -s --max-time 4 "$ODATA/Orders($NEW_ID)" | python3 -c '
import json,sys
d=json.load(sys.stdin); print("%s|%s" % (d.get("status"), d.get("approvedBy") or "-"))' 2>/dev/null)
      [[ "${RESULT%%|*}" != "PENDING" ]] && break
    done
    if [[ "$RESULT" == "APPROVED|auto-rule" ]]; then
      ok "tam zincir çalıştı: CAP -> n8n -> IF -> CAP approve  (${i}s)"
      warn "listede 1 prova siparişi kaldı - temiz başlangıç için CAP'i yeniden başlat"
    else
      bad "beklenen APPROVED/auto-rule değil, gelen: ${RESULT:-yanıt yok}"; note
    fi
  fi
fi

head1 "Sonuç"
if (( FAILED )); then
  bad "Demo hazır DEĞİL - yukarıdaki kırmızıları düzelt"
  exit 1
else
  ok "Her şey hazır. İyi sunumlar!"
fi
