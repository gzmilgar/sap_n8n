#!/usr/bin/env zsh
# Form modunda (04) onay bekleyen son siparişin onay formu adresini bulur ve açar.
# Sahnede n8n'in Executions ekranında onayFormUrl aramak yerine:
#
#   ./form-url.sh            bekleyen son formu bul ve tarayıcıda aç
#   ./form-url.sh --print    sadece adresi yaz, açma
#   ./form-url.sh <sipariş-id>   belirli bir siparişin formu
#
# n8n'in SQLite veritabanını salt okunur okur; n8n açıkken çalışır.
set -euo pipefail
source "${0:A:h}/lib-demo.sh"
DB="$HOME/.n8n/database.sqlite"
PRINT_ONLY=0; ORDER_ID=""
for a in "$@"; do
  case "$a" in
    --print) PRINT_ONLY=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) ORDER_ID="$a" ;;
  esac
done
[[ -f "$DB" ]] || { bad "n8n veritabanı yok: $DB"; exit 1; }

URL=$(python3 - "$DB" "$ORDER_ID" <<'PY'
import json, sqlite3, sys
db, order_id = sys.argv[1], sys.argv[2]
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
q = ("SELECT e.id, d.data FROM execution_entity e JOIN execution_data d ON d.executionId = e.id "
     "WHERE e.workflowId = 'demo04' AND e.status = 'waiting' "
     "AND e.startedAt >= datetime('now', '-12 hours')")   # eski oturumlardan kalan artiklari atla
args = ()
if order_id:
    q += " AND d.data LIKE ?"; args = (f"%{order_id}%",)
row = con.execute(q + " ORDER BY e.id DESC LIMIT 1", args).fetchone()
if not row:
    sys.exit(2)
arr = json.loads(row[1])
def deref(v, n=0):                      # n8n 'flatted' format
    if n > 80: return None
    if isinstance(v, str):
        t = arr[int(v)]; return t if isinstance(t, str) else deref(t, n + 1)
    if isinstance(v, list): return [deref(x, n + 1) for x in v]
    if isinstance(v, dict): return {k: deref(x, n + 1) for k, x in v.items()}
    return v
data = deref(arr[0])
out = data["resultData"]["runData"]["Siparis Bilgileri"][-1]["data"]["main"][0][0]["json"]
print(f'{row[0]}|{out.get("ID","")}|{out.get("amount","")}|{out.get("onayFormUrl","")}')
PY
) || { bad "Form bekleyen 04 execution'ı yok. Önce eşik üstü bir sipariş aç: ./scripts/create-order.sh -a 15000"; exit 1; }

EXEC_ID="${URL%%|*}"; REST="${URL#*|}"; OID="${REST%%|*}"; REST="${REST#*|}"; AMT="${REST%%|*}"; FORM="${REST#*|}"
[[ -n "$FORM" ]] || { bad "onayFormUrl boş (execution $EXEC_ID)"; exit 1; }
if [[ "$FORM" == *trycloudflare.com* ]]; then
  warn "Form adresi tünel üzerinden üretilmiş; n8n tünelsiz başlatılmalı (./scripts/start-demo.sh --n8n). localhost'a çeviriyorum."
  FORM="http://localhost:5678${FORM#*trycloudflare.com}"
fi
head1 "Onay formu"
info "sipariş  : $OID  ($AMT TRY)"
info "execution: $EXEC_ID"
print -r -- "  $FORM"
if (( ! PRINT_ONLY )); then command -v open >/dev/null && open "$FORM" && ok "tarayıcıda açıldı"; fi
