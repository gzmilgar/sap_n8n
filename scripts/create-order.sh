#!/usr/bin/env zsh
# Create a test order in CAP so the n8n approval loop fires.
#
#   ./create-order.sh -a 15000        high value  -> Telegram/Form approval
#   ./create-order.sh -a 500          low value   -> auto-approved
#   ./create-order.sh                 no amount   -> CAP calculates qty x unitPrice
#   ./create-order.sh -p "Dijital Manometre" -q 3
set -u
source "${0:A:h}/lib-demo.sh"

CUSTOMER="Anadolu Makina A.Ş."
PRODUCT="Endüstriyel Filtre Kartuşu"
QTY=40
AMOUNT=""

while getopts "a:c:p:q:h" opt; do
  case $opt in
    a) AMOUNT="$OPTARG" ;;
    c) CUSTOMER="$OPTARG" ;;
    p) PRODUCT="$OPTARG" ;;
    q) QTY="$OPTARG" ;;
    h) show_usage "$0"; exit 0 ;;
    *) exit 1 ;;
  esac
done

if ! cap_up; then
  bad "CAP ayakta değil ($ODATA)"
  info "Önce çalıştır:  ./scripts/start-demo.sh"
  exit 1
fi

# Only send amount when the caller supplied one, otherwise let CAP derive it.
if [[ -n "$AMOUNT" ]]; then
  BODY=$(printf '{"customer":%s,"product":%s,"qty":%s,"amount":%s}' \
    "$(print -r -- "$CUSTOMER" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')" \
    "$(print -r -- "$PRODUCT"  | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')" \
    "$QTY" "$AMOUNT")
else
  BODY=$(printf '{"customer":%s,"product":%s,"qty":%s}' \
    "$(print -r -- "$CUSTOMER" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')" \
    "$(print -r -- "$PRODUCT"  | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')" \
    "$QTY")
fi

head1 "POST $ODATA/Orders"
info "$BODY"

RESP=$(curl -s -w $'\n%{http_code}' -X POST "$ODATA/Orders" \
  -H 'Content-Type: application/json' --data-binary "$BODY")
CODE="${RESP##*$'\n'}"
JSON="${RESP%$'\n'*}"

if [[ "$CODE" != "201" ]]; then
  bad "Sipariş oluşturulamadı (HTTP $CODE)"
  print -r -- "$JSON" | python3 -m json.tool 2>/dev/null || print -r -- "$JSON"
  exit 1
fi

print -r -- "$JSON" | ORDER_ODATA="$ODATA" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
G = "\033[32m"; Y = "\033[33m"; D = "\033[2m"; R = "\033[0m"
print(f"  {G}✅{R} Sipariş oluşturuldu")
print(f"     ID       : {d['"'"'ID'"'"']}")
print(f"     Müşteri  : {d['"'"'customer'"'"']}")
print(f"     Ürün     : {d['"'"'product'"'"']}")
print(f"     Adet     : {d['"'"'qty'"'"']}")
print(f"     Tutar    : {d['"'"'amount'"'"']} {d['"'"'currency'"'"']}")
print(f"     Durum    : {d['"'"'status'"'"']}")
print()
if float(d["amount"]) > 10000:
    print(f"  {Y}→{R} 10.000 üstü: onay istenecek (Telegram, ya da offline modda n8n formu)")
else:
    print(f"  {Y}→{R} 10.000 altı: birkaç saniyede otomatik onaylanmalı")
print()
print(f"  {D}Sonucu izle:{R}")
print(f"  ./scripts/watch-order.sh {d['"'"'ID'"'"']}")
'
