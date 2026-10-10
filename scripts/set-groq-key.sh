#!/usr/bin/env zsh
# Agent'ı (02) Groq üzerindeki açık kaynak Llama modeline geçirir: anahtarı test eder, n8n credential'ı
# olarak kaydeder, "Chat Model" node'unu Groq Chat Model'e çevirir (hem n8n'de hem repo JSON'unda) ve yayınlar.
# Ücretsiz Groq katmanı: günde binlerce istek, 1-2 sn yanıt, tool calling destekli.
#
#   ./set-groq-key.sh gsk_...                      llama-3.3-70b-versatile ile
#   ./set-groq-key.sh gsk_... --model <model-id>   başka bir Groq modeli
#   ./set-groq-key.sh gsk_... --keep-repo          repo JSON'una dokunma, sadece n8n
#
# Anahtar: https://console.groq.com/keys  (ücretsiz hesap)
# n8n kapalı olmalı: ./scripts/stop-demo.sh --n8n   -  sonra:  ./scripts/start-demo.sh --n8n
# Gemini'ye dönmek: ./scripts/set-gemini-key.sh <AIza...>  ya da n8n'de Chat Model node'unu değiştir.
set -euo pipefail
source "${0:A:h}/lib-demo.sh"

KEY="${1:-}"; MODEL="llama-3.3-70b-versatile"; KEEP_REPO=0
shift || true
while (( $# )); do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --keep-repo) KEEP_REPO=1; shift ;;
    *) bad "bilinmeyen seçenek: $1"; exit 1 ;;
  esac
done
if [[ -z "$KEY" ]]; then
  bad "Kullanım: ./set-groq-key.sh <gsk_...> [--model <id>] [--keep-repo]"; exit 1
fi
[[ "$KEY" == gsk_* ]] || warn "Anahtar 'gsk_' ile başlamıyor - yine de deneyeceğim"
CRED_ID="groqkey01"; CRED_NAME="Groq account"

head1 "1 · Anahtar test ediliyor"
RESP=$(curl -s --max-time 20 https://api.groq.com/openai/v1/models -H "Authorization: Bearer $KEY" || true)
RES=$(print -r -- "$RESP" | python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except Exception: print('PARSE'); raise SystemExit
if 'error' in d: print('ERR|' + str(d['error'].get('message', ''))[:160]); raise SystemExit
ids = [m['id'] for m in d.get('data', [])]
print('OK|%d|%s' % (len(ids), 'yes' if '$MODEL' in ids else 'no'))
")
case "$RES" in
  OK\|*) COUNT="${${RES#OK|}%%|*}"; HAS="${RES##*|}"; ok "Anahtar geçerli - $COUNT model erişilebilir"
         if [[ "$HAS" == "yes" ]]; then ok "$MODEL kullanılabilir"; else bad "$MODEL bu hesapta yok; --model ile başka bir model ver"; exit 1; fi ;;
  ERR\|*) bad "Groq anahtarı reddetti: ${RES#ERR|}"; exit 1 ;;
  *)      bad "Groq'a ulaşılamadı (internet?)"; exit 1 ;;
esac

head1 "2 · n8n credential'ı kaydediliyor"
if n8n_up; then bad "n8n çalışıyor - önce durdur:  ./scripts/stop-demo.sh --n8n"; exit 2; fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
python3 - "$TMP/cred.json" "$CRED_ID" "$CRED_NAME" "$KEY" <<'PY'
import json, sys
out, cid, name, key = sys.argv[1:5]
json.dump([{"id": cid, "name": name, "type": "groqApi", "data": {"apiKey": key}}], open(out, "w"))
PY
n8n import:credentials --input="$TMP/cred.json" >/dev/null 2>&1 \
  && ok "'$CRED_NAME' kaydedildi" || { bad "credential kaydedilemedi"; exit 1 }

head1 "3 · Chat Model node'u Groq'a çevriliyor"
python3 - "$HOME/.n8n/database.sqlite" "$CRED_ID" "$CRED_NAME" "$MODEL" "$REPO_ROOT/n8n-workflows/02-order-agent.json" "$KEEP_REPO" <<'PY'
import json, sqlite3, sys
db_path, cid, cname, model, repo_json, keep_repo = sys.argv[1:7]
def to_groq(n, cred_id):
    n["type"] = "@n8n/n8n-nodes-langchain.lmChatGroq"; n["typeVersion"] = 1
    n["parameters"] = {"model": model, "options": {"temperature": 0}}
    n["credentials"] = {"groqApi": {"id": cred_id, "name": cname}}
    n["notes"] = f"Groq uzerinde acik kaynak model ({model}). Retry On Fail acik. Gemini'ye donmek: set-gemini-key.sh"
    n.setdefault("retryOnFail", True); n.setdefault("maxTries", 3); n.setdefault("waitBetweenTries", 3000)
db = sqlite3.connect(db_path)
nodes = json.loads(db.execute("SELECT nodes FROM workflow_entity WHERE id='demo02'").fetchone()[0])
hit = False
for n in nodes:
    if n.get("name") == "Chat Model": to_groq(n, cid); hit = True
if not hit: print("  Chat Model node'u bulunamadi"); raise SystemExit(1)
db.execute("UPDATE workflow_entity SET nodes=?, updatedAt=STRFTIME('%Y-%m-%d %H:%M:%f','NOW') WHERE id='demo02'", (json.dumps(nodes, ensure_ascii=False),)); db.commit()
print(f"  n8n: Chat Model -> Groq / {model}")
if keep_repo != "1":
    w = json.load(open(repo_json, encoding="utf-8"))
    for n in w["nodes"]:
        if n.get("name") == "Chat Model": to_groq(n, "REPLACE_WITH_YOUR_CREDENTIAL_ID")
    json.dump(w, open(repo_json, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(repo_json, "a").write("\n")
    print("  repo: n8n-workflows/02-order-agent.json guncellendi")
PY
ok "02 / Chat Model -> Groq ($MODEL)"

head1 "4 · Yayınlanıyor"
"${0:A:h}/publish-workflows.sh" 2>&1 | grep -E '02|❌' || true

print -r -- ""
info "Şimdi:  ./scripts/start-demo.sh --n8n"
info "Sonra:  http://localhost:4004/chat.html"
