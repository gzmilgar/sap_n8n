#!/usr/bin/env zsh
# Pick a Gemini model this key can actually use for tool calling, and write it
# into workflow 02. Google retires model ids for new accounts, so the id shipped
# in the repo can 404 even with a valid key.
#
#   ./pick-gemini-model.sh                 en iyi modeli seç ve ayarla
#   ./pick-gemini-model.sh --list          sadece listele
#   ./pick-gemini-model.sh models/xyz      belirli bir modeli dene
set -u
source "${0:A:h}/lib-demo.sh"

for arg in "$@"; do case "$arg" in -h|--help) show_usage "$0"; exit 0 ;; esac; done

if n8n_up; then
  bad "n8n çalışıyor - önce durdur:  ./scripts/stop-demo.sh --n8n"
  exit 2
fi

CRED_ID=$(sqlite3 "$HOME/.n8n/database.sqlite" \
  "SELECT id FROM credentials_entity WHERE type='googlePalmApi' LIMIT 1;" 2>/dev/null)
if [[ -z "$CRED_ID" ]]; then
  bad "n8n'de Gemini credential'ı yok"
  info "Önce n8n'de 'Google Gemini(PaLM) Api' credential'ı oluştur"
  exit 1
fi

# The key is exported to a private temp file, read once by the picker, removed.
TMP=$(mktemp -d); chmod 700 "$TMP"
n8n export:credentials --id="$CRED_ID" --decrypted --output="$TMP/c.json" >/dev/null 2>&1 \
  || { bad "credential okunamadı"; rm -rf "$TMP"; exit 1 }

python3 "${0:A:h}/gemini_pick.py" \
  "$TMP/c.json" "$HOME/.n8n/database.sqlite" "$WF_DIR/02-order-agent.json" "$@"
RC=$?
rm -rf "$TMP"

(( RC == 0 )) && { print -r -- ""; info "Şimdi:  ./scripts/start-demo.sh --tunnel" }
exit $RC
