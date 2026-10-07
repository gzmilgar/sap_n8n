#!/usr/bin/env zsh
# One-time macOS setup:
#   1. CAP dependencies + .env
#   2. the "CAP Webhook Key" Header Auth credential, created for you
#   3. the 4 workflows, imported into n8n with that credential already wired
#
#   --force   re-import even when the workflows are already in n8n
#             (this RESETS the credential pickers and <CHAT_ID> you set in the UI)
set -u
source "${0:A:h}/lib-demo.sh"

CRED_ID="capwebhookkey01"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) show_usage "$0"; exit 0 ;;
  esac
done

head1 "SAP CAP + n8n · macOS kurulumu"

# --- tools -------------------------------------------------------------------
if ! ensure_node_on_path; then bad "node bulunamadı"; exit 1; fi
ok "node $(node --version)"
command -v cds >/dev/null 2>&1 && ok "cds hazır" || { bad "cds yok  ->  npm install -g @sap/cds-dk"; exit 1; }
command -v n8n >/dev/null 2>&1 && ok "n8n $(n8n --version 2>/dev/null | tail -1)" || { bad "n8n yok  ->  npm install -g n8n"; exit 1; }

# --- CAP ---------------------------------------------------------------------
head1 "1 · CAP projesi"
if [[ ! -f "$CAP_DIR/.env" ]]; then
  cp "$CAP_DIR/.env.example" "$CAP_DIR/.env"; ok ".env oluşturuldu"
else
  ok ".env zaten var"
fi
KEY=$(env_value N8N_WEBHOOK_KEY)
[[ -z "$KEY" ]] && { bad ".env içinde N8N_WEBHOOK_KEY yok"; exit 1; }
info "webhook anahtarı: $KEY"

( cd "$CAP_DIR" && npm install --no-audit --no-fund >/dev/null 2>&1 ) \
  && ok "npm install tamam" || { bad "npm install başarısız"; exit 1; }

# --- n8n import --------------------------------------------------------------
head1 "2 · n8n credential + workflow import"
if n8n_up; then
  warn "n8n çalışıyor. Import için önce durdur:  ./scripts/stop-demo.sh"
  exit 1
fi

# Re-importing rewrites every node, which throws away the Telegram / OpenAI
# credential you picked in the UI and the <CHAT_ID> you typed. Only do that
# when explicitly asked.
N8N_DB="$HOME/.n8n/database.sqlite"
if (( ! FORCE )) && [[ -f "$N8N_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
  EXISTING=$(sqlite3 "$N8N_DB" "SELECT count(*) FROM workflow_entity WHERE id LIKE 'demo0%';" 2>/dev/null || print 0)
  if [[ "${EXISTING:-0}" -gt 0 ]]; then
    warn "n8n'de zaten $EXISTING demo workflow'u var - import atlandı"
    info "Tekrar import edersen n8n arayüzünde seçtiğin Telegram/OpenAI"
    info "credential'ları ve <CHAT_ID> SIFIRLANIR."
    info "Yine de istiyorsan:  ./scripts/setup-mac.sh --force"
    print -r -- ""
    ok "CAP tarafı hazır. Kontrol:  ./scripts/check-demo.sh"
    exit 0
  fi
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Header Auth credential, value taken straight from .env so the two cannot drift.
python3 - "$TMP/creds.json" "$CRED_ID" "$KEY" <<'PY'
import json, sys
out, cred_id, key = sys.argv[1], sys.argv[2], sys.argv[3]
json.dump([{
    "id": cred_id,
    "name": "CAP Webhook Key",
    "type": "httpHeaderAuth",
    "data": {"name": "X-API-Key", "value": key},
}], open(out, "w"), ensure_ascii=False)
PY

# Copy the workflows and point their Header Auth reference at the credential we
# just created. Telegram / OpenAI keep their placeholders - those hold secrets
# and must be picked in the n8n UI.
python3 - "$WF_DIR" "$TMP/wf" "$CRED_ID" <<'PY'
import json, os, glob, sys, collections
src_dir, dst_dir, cred_id = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(dst_dir, exist_ok=True)
for src in sorted(glob.glob(os.path.join(src_dir, "*.json"))):
    wf = json.load(open(src), object_pairs_hook=collections.OrderedDict)
    wf["id"] = "demo" + os.path.basename(src)[:2]
    for node in wf["nodes"]:
        for ctype, cred in (node.get("credentials") or {}).items():
            if ctype == "httpHeaderAuth":
                cred["id"] = cred_id
    json.dump(wf, open(os.path.join(dst_dir, os.path.basename(src)), "w"),
              indent=2, ensure_ascii=False)
    print("  staged", os.path.basename(src))
PY

n8n import:credentials --input="$TMP/creds.json" >/dev/null 2>&1 \
  && ok "'CAP Webhook Key' credential oluşturuldu" \
  || { bad "credential import başarısız"; exit 1; }

n8n import:workflow --separate --input="$TMP/wf" 2>&1 | tail -1 | sed 's/^/  /'
ok "4 workflow import edildi (webhook credential'ı bağlı)"

# --- what is still manual ----------------------------------------------------
head1 "3 · Senin yapman gerekenler (n8n arayüzünde)"
cat <<'TXT'
  n8n'i başlat:  ./scripts/start-demo.sh   ->  http://localhost:5678

  a) Credentials -> New  ile ikisini oluştur (secret içerdikleri için elle):
       • "Telegram account"  (bot token)
       • "Anthropic account" (sk-ant-... API key, console.anthropic.com)

  b) 01 ve 03'teki Telegram node'larında kendi credential'ını seç
     02'deki "Chat Model" node'unda Anthropic credential'ını seç

  c) 01 ve 03'teki <CHAT_ID> yerine kendi chat id'ni yaz

  d) "01 - Order Approval" workflow'unu aç -> sağ üst -> Activate
     (offline prova için 04'ü de aktif et)

  NOT: import her seferinde workflow'ları PASİF getirir - (d) adımını
       her --force sonrasında tekrarlaman gerekir.

  Sonra:  ./scripts/check-demo.sh
TXT
