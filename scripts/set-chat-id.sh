#!/usr/bin/env zsh
# Put your Telegram chat id into workflows 01 and 03, in both places at once:
# the JSON files in this repo and the copies already imported into n8n.
#
#   ./set-chat-id.sh 123456789
#   ./set-chat-id.sh -1001234567890     (grup sohbeti)
#
# n8n kapalı olmalı - aktif workflow'ları bellekte tutar.
set -u
source "${0:A:h}/lib-demo.sh"

for arg in "$@"; do
  case "$arg" in -h|--help) show_usage "$0"; exit 0 ;; esac
done

CHAT_ID="${1:-}"
if [[ -z "$CHAT_ID" ]]; then
  bad "Kullanım: ./set-chat-id.sh <chat-id>"
  info "Chat id'ni bulmak için Telegram'da @get_id_bot ile konuş."
  exit 2
fi

# Guard against pasting the bot token here by mistake.
if [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
  bad "'$CHAT_ID' bir chat id'ye benzemiyor (sadece rakam, grup ise başında -)"
  info "Bot token'ı değil, chat id'yi ver. @get_id_bot sana chat id'yi söyler."
  exit 2
fi

if n8n_up; then
  bad "n8n çalışıyor - önce durdur:  ./scripts/stop-demo.sh"
  exit 2
fi

head1 "Chat ID ayarlanıyor: $CHAT_ID"

# Both targets are updated by one script: the repo files, and - by touching only
# the `nodes` column - the copies inside n8n, so credentials picked in the UI survive.
python3 - "$WF_DIR" "$HOME/.n8n/database.sqlite" "$CHAT_ID" <<'PY'
import collections, glob, json, os, sqlite3, sys

wf_dir, db_path, chat_id = sys.argv[1], sys.argv[2], sys.argv[3]
PLACEHOLDER = "<CHAT_ID>"


def patch(nodes):
    """Fill the placeholder in node parameters and in the now-stale notes.

    Returns (parameter_hits, changed_anything) - notes alone still need saving,
    but only parameter hits are worth reporting as real work.
    """
    hits = 0
    touched = False
    for node in nodes:
        for key, val in (node.get("parameters") or {}).items():
            if isinstance(val, str) and PLACEHOLDER in val:
                node["parameters"][key] = val.replace(PLACEHOLDER, chat_id)
                hits += 1
                touched = True
        notes = node.get("notes")
        if isinstance(notes, str) and PLACEHOLDER in notes:
            node["notes"] = f"Chat id: {chat_id}"
            touched = True
    return hits, touched


# --- 1) the JSON files in this repo -----------------------------------------
for path in sorted(glob.glob(os.path.join(wf_dir, "*.json"))):
    wf = json.load(open(path), object_pairs_hook=collections.OrderedDict)
    hits, touched = patch(wf["nodes"])
    if touched:
        json.dump(wf, open(path, "w"), indent=2, ensure_ascii=False)
        open(path, "a").write("\n")
        if hits:
            print(f"  dosya: {os.path.basename(path):<34} {hits} alan")

# --- 2) the copies already inside n8n ---------------------------------------
if os.path.exists(db_path):
    db = sqlite3.connect(db_path)
    rows = db.execute(
        "SELECT id, name, nodes FROM workflow_entity WHERE nodes LIKE ?",
        (f"%{PLACEHOLDER}%",),
    ).fetchall()
    n8n_hits = 0
    for wid, name, nodes_json in rows:
        nodes = json.loads(nodes_json)
        hits, touched = patch(nodes)
        if touched:
            db.execute("UPDATE workflow_entity SET nodes = ? WHERE id = ?",
                       (json.dumps(nodes), wid))
        if hits:
            n8n_hits += hits
            print(f"  n8n  : {name:<34} {hits} alan")
    db.commit()
    if not n8n_hits:
        print("  n8n  : doldurulacak alan yoktu (zaten ayarlıymış)")
else:
    print("  n8n  : ~/.n8n/database.sqlite yok - once ./scripts/setup-mac.sh")

# --- 3) verify: only parameters count, notes are free text -------------------
left = sum(
    1
    for path in glob.glob(os.path.join(wf_dir, "*.json"))
    for node in json.load(open(path))["nodes"]
    for val in (node.get("parameters") or {}).values()
    if isinstance(val, str) and PLACEHOLDER in val
)
if left:
    print(f"  UYARI: {left} alanda hâlâ {PLACEHOLDER} var")
PY

print -r -- ""
ok "Bitti. Şimdi:  ./scripts/start-demo.sh"
