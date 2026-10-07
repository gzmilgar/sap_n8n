#!/usr/bin/env zsh
# Act 2 without a live LLM: walk the agent's three tool calls by hand, at
# speaking pace, so you can narrate the architecture even when the model is
# unavailable (no credits, no internet, API hiccup on stage).
#
#   ./agent-demo.sh                 varsayılan senaryo
#   ./agent-demo.sh -c Anadolu -p Filtre -q 40
#   ./agent-demo.sh --fast          duraklamasız
set -u
source "${0:A:h}/lib-demo.sh"

CUST_TERM="Anadolu"; PROD_TERM="Filtre"; QTY=40; PAUSE=2.5
for arg in "$@"; do case "$arg" in -h|--help) show_usage "$0"; exit 0 ;; esac; done
while getopts "c:p:q:f-:" opt; do
  case $opt in
    c) CUST_TERM="$OPTARG" ;; p) PROD_TERM="$OPTARG" ;; q) QTY="$OPTARG" ;;
    f) PAUSE=0 ;; -) [[ "$OPTARG" == fast ]] && PAUSE=0 ;;
  esac
done

cap_up || { bad "CAP kapalı -> ./scripts/start-demo.sh"; exit 1 }
beat() { (( PAUSE > 0 )) && sleep $PAUSE }

urlenc() { python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1" }

# Read one field out of an OData collection, tolerating error bodies.
odata_first() {  # $1 = url, $2 = field
  curl -s "$1" | python3 -c "
import json, sys
try:
    v = json.load(sys.stdin).get('value', [])
except Exception:
    v = []
print(v[0]['$2'] if v else '')
" 2>/dev/null
}

head1 "Kullanıcının isteği"
print -r -- "  \"$CUST_TERM'ya $QTY kutu $PROD_TERM siparişi aç\""
beat

# --- tool 1 ------------------------------------------------------------------
head1 "1 · listProducts  →  ürünü ve fiyatı SAP'den sor"
info "GET /Products?\$filter=contains(name,'$PROD_TERM')"
beat
PQ="$ODATA/Products?\$filter=contains(name,'$(urlenc "$PROD_TERM")')"
PNAME=$(odata_first "$PQ" name)
PRICE=$(odata_first "$PQ" unitPrice)
if [[ -z "$PNAME" ]]; then
  bad "Ürün bulunamadı - agent burada DURUR ve sipariş açmaz"
  info "Uydurma ürünle sipariş açılamamasının sebebi bu."
  exit 1
fi
ok "$PNAME   birim fiyat: $PRICE TRY"
beat

# --- tool 2 ------------------------------------------------------------------
head1 "2 · getCustomer  →  müşteriyi doğrula"
info "GET /Customers?\$filter=contains(name,'$CUST_TERM')"
beat
CNAME=$(odata_first "$ODATA/Customers?\$filter=contains(name,'$(urlenc "$CUST_TERM")')" name)
if [[ -z "$CNAME" ]]; then
  bad "Müşteri bulunamadı - agent burada DURUR"
  exit 1
fi
ok "$CNAME"
beat

# --- the arithmetic the agent shows the user ---------------------------------
head1 "3 · Tutarı hesapla"
TOTAL=$(python3 -c "print('%.2f' % ($QTY * float('$PRICE')))")
print -r -- "  $QTY × $PRICE = ${C_BOLD}$TOTAL TRY${C_RESET}"
beat

# --- tool 3 ------------------------------------------------------------------
head1 "4 · createOrder  →  SAP'de siparişi aç"
info "POST /Orders  {customer, product, qty}"
beat
BODY=$(python3 -c "
import json
print(json.dumps({'customer': '''$CNAME''', 'product': '''$PNAME''', 'qty': $QTY}))")
RESP=$(curl -s -X POST "$ODATA/Orders" -H 'Content-Type: application/json' --data-binary "$BODY")
print -r -- "$RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
G='\033[32m'; R='\033[0m'
print(f'  {G}✅{R} Siparis No: {d[\"ID\"]}')
print(f'     {d[\"customer\"]} · {d[\"product\"]} · {d[\"qty\"]} adet · {d[\"amount\"]} {d[\"currency\"]} · {d[\"status\"]}')
open('/tmp/agent-demo-id.txt','w').write(d['ID'])
"
beat
head1 "5 · Döngü kapanıyor"
print -r -- "  CAP webhook'u attı → Perde 1'deki workflow devreye girdi."
print -r -- "  Tutar 10.000'in üstünde → onay istendi."
print -r -- ""
info "Durumu izle:  ./scripts/watch-order.sh \$(cat /tmp/agent-demo-id.txt)"
