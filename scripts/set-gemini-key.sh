#!/usr/bin/env zsh
# Wire a free Google Gemini key into the demo in one step: test it, store it as
# an n8n credential, and bind it to workflow 02's Chat Model node.
#
#   ./set-gemini-key.sh AIza...
#
# Anahtarı buradan al (ücretsiz, kredi kartı istemez):
#   https://aistudio.google.com/apikey
set -u
source "${0:A:h}/lib-demo.sh"

for arg in "$@"; do case "$arg" in -h|--help) show_usage "$0"; exit 0 ;; esac; done

KEY="${1:-}"
CRED_ID="geminikey01"
CRED_NAME="Google Gemini account"
MODEL="models/gemini-2.5-flash"

if [[ -z "$KEY" ]]; then
  bad "Kullanım: ./set-gemini-key.sh <API-key>"
  info "Ücretsiz anahtar: https://aistudio.google.com/apikey"
  exit 2
fi
if [[ "$KEY" != AIza* ]]; then
  warn "Anahtar 'AIza' ile başlamıyor - yine de deneyeceğim"
fi

# --- 1) does the key actually work? -----------------------------------------
head1 "1 · Anahtar test ediliyor"
RESP=$(curl -s --max-time 25 "https://generativelanguage.googleapis.com/v1beta/models?key=$KEY")
OK=$(print -r -- "$RESP" | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: print('PARSE'); raise SystemExit
if 'error' in d:
    e = d['error']
    print('ERR|%s|%s' % (e.get('status', '?'), e.get('message', '')[:160]))
else:
    names = [m['name'] for m in d.get('models', [])]
    print('OK|%d|%s' % (len(names), 'yes' if 'models/gemini-2.5-flash' in names else 'no'))
")

case "$OK" in
  OK\|*)
    COUNT="${${OK#OK|}%%|*}"; HAS="${OK##*|}"
    ok "Anahtar geçerli - $COUNT model erişilebilir"
    if [[ "$HAS" == "yes" ]]; then ok "$MODEL kullanılabilir"
    else warn "$MODEL listede yok; node'da modeli değiştirmen gerekebilir"; fi
    ;;
  ERR\|*)
    bad "Google anahtarı reddetti"
    print -r -- "     ${OK#ERR|}" | tr '|' ' '
    info "Yeni anahtar: https://aistudio.google.com/apikey"
    exit 1 ;;
  *)
    bad "Google'a ulaşılamadı (internet?)"; exit 1 ;;
esac

# --- 2) store it as an n8n credential ----------------------------------------
head1 "2 · n8n credential'ı oluşturuluyor"
if n8n_up; then
  bad "n8n çalışıyor - önce durdur:  ./scripts/stop-demo.sh --n8n"
  exit 2
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
python3 - "$TMP/cred.json" "$CRED_ID" "$CRED_NAME" "$KEY" <<'PY'
import json, sys
out, cid, name, key = sys.argv[1:5]
json.dump([{
    "id": cid, "name": name, "type": "googlePalmApi",
    "data": {"host": "https://generativelanguage.googleapis.com", "apiKey": key},
}], open(out, "w"))
PY
n8n import:credentials --input="$TMP/cred.json" >/dev/null 2>&1 \
  && ok "'$CRED_NAME' kaydedildi" || { bad "credential kaydedilemedi"; exit 1 }

# --- 3) bind it to the Chat Model node ---------------------------------------
head1 "3 · Chat Model node'una bağlanıyor"
python3 - "$HOME/.n8n/database.sqlite" "$CRED_ID" "$CRED_NAME" <<'PY'
import json, sqlite3, sys
db_path, cid, cname = sys.argv[1:4]
db = sqlite3.connect(db_path)
row = db.execute("SELECT nodes FROM workflow_entity WHERE id='demo02'").fetchone()
if not row:
    print("  demo02 bulunamadi - once ./scripts/setup-mac.sh"); raise SystemExit(1)
nodes = json.loads(row[0])
hit = False
for n in nodes:
    if n.get("name") == "Chat Model":
        n["credentials"] = {"googlePalmApi": {"id": cid, "name": cname}}
        hit = True
if hit:
    db.execute("UPDATE workflow_entity SET nodes=?, updatedAt=datetime('now') WHERE id='demo02'",
               (json.dumps(nodes),))
    db.commit()
    print("  baglandi")
PY
ok "02 / Chat Model -> $CRED_NAME"

print -r -- ""
info "Şimdi:  ./scripts/start-demo.sh --tunnel"
info "Sonra 02'yi aç, Chat panelinden dene."
